#!/usr/bin/perl
# ProPre2.0 timer server - Perl edition.
# Perl comes built into every Mac, so nothing needs to be installed.
# Does exactly what server.py does: same addresses, same rules, same timers.
#
#   perl server.pl            run in the foreground (Ctrl+C to stop)
#   perl server.pl --daemon   run in the background, logging to server.log
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use JSON::PP;
use Time::HiRes ();
use FindBin qw($Bin);
use POSIX qw(setsid strftime);
use Sys::Hostname ();

my $ROOT = $Bin;
my $PORT = $ENV{PROPRE_PORT} || 3000;
# Listens on the network so a second computer (e.g. E2) can mirror the output screen.
# Other computers are view-only: they can fetch the live state and output.html, nothing else.
# Set PROPRE_HOST=127.0.0.1 to keep the server private to this computer.
my $HOST = $ENV{PROPRE_HOST} || '0.0.0.0';
my $DATA = $ENV{PROPRE_DATA} || "$ROOT/timers.json";
my $LEGACY_DB = "$ROOT/timers.db";   # timers from the old Python version are imported once

my @TYPES     = qw(countdown countup altar-call blank);
my @POSITIONS = qw(top-left top-center top-right middle-left middle-center middle-right
                   bottom-left bottom-center bottom-right);
my @SIZES     = qw(small medium large);
my @COLOURS   = qw(white yellow red);
my %STATIC_TYPES = ('.html' => 'text/html; charset=utf-8', '.ttf' => 'font/ttf');
my %REASON = (200 => 'OK', 201 => 'Created', 400 => 'Bad Request', 403 => 'Forbidden',
              404 => 'Not Found', 500 => 'Internal Server Error');

my $JSON = JSON::PP->new->utf8->allow_nonref->canonical;

my @timers;
my $next_id = 1;
my %live = (timer => undef, elapsed => 0, isRunning => 0, stamp => Time::HiRes::time());

# ---------------------------------------------------------------- storage

sub now_stamp { return strftime('%Y-%m-%d %H:%M:%S', gmtime()); }

sub norm {
    my ($r) = @_;
    return undef unless ref($r) eq 'HASH' && defined $r->{id} && defined $r->{name};
    return {
        id                => int($r->{id}),
        name              => "$r->{name}",
        duration_seconds  => int($r->{duration_seconds} || 0),
        type              => (defined $r->{type} ? "$r->{type}" : 'countdown'),
        position          => (defined $r->{position} ? "$r->{position}" : 'middle-center'),
        size              => (defined $r->{size} ? "$r->{size}" : 'large'),
        colour            => (defined $r->{colour} ? "$r->{colour}" : 'white'),
        show_title        => (!defined $r->{show_title} || $r->{show_title} ? 1 : 0),
        show_current_time => ($r->{show_current_time} ? 1 : 0),
        created_at        => (defined $r->{created_at} ? "$r->{created_at}" : now_stamp()),
        updated_at        => (defined $r->{updated_at} ? "$r->{updated_at}" : now_stamp()),
    };
}

# Fresh values every time, so numbers are written as numbers and text as text.
sub out {
    my ($t) = @_;
    return {
        id                => 0 + $t->{id},
        name              => "$t->{name}",
        duration_seconds  => 0 + $t->{duration_seconds},
        type              => "$t->{type}",
        position          => "$t->{position}",
        size              => "$t->{size}",
        colour            => "$t->{colour}",
        show_title        => ($t->{show_title} ? 1 : 0),
        show_current_time => ($t->{show_current_time} ? 1 : 0),
        created_at        => "$t->{created_at}",
        updated_at        => "$t->{updated_at}",
    };
}

sub save {
    my $tmp = "$DATA.tmp";
    my $fh;
    unless (open($fh, '>:raw', $tmp)) { warn "Could not save timers: $!\n"; return; }
    print $fh JSON::PP->new->utf8->pretty->canonical->encode(
        { next_id => 0 + $next_id, timers => [ map { out($_) } @timers ] });
    close $fh;
    rename $tmp, $DATA or warn "Could not save timers: $!\n";
}

sub migrate_legacy {
    return 0 unless -f $LEGACY_DB;
    my $raw = '';
    eval {
        open(my $ph, '-|', 'sqlite3', '-json', $LEGACY_DB,
             'SELECT * FROM timers ORDER BY created_at ASC, id ASC') or die "no sqlite3\n";
        local $/;
        $raw = <$ph>;
        close $ph;
    };
    return 0 unless defined $raw && length $raw;
    my $rows = eval { JSON::PP->new->utf8->decode($raw) };
    return 0 unless ref($rows) eq 'ARRAY';
    my $count = 0;
    for my $r (@$rows) {
        my $t = norm($r) or next;
        push @timers, $t;
        $next_id = $t->{id} + 1 if $t->{id} >= $next_id;
        $count++;
    }
    return $count;
}

sub load_timers {
    if (-f $DATA) {
        my $text = do { local $/; open(my $fh, '<:raw', $DATA) or die "Cannot read $DATA: $!\n"; <$fh> };
        my $d = eval { JSON::PP->new->utf8->decode($text) };
        if (ref($d) eq 'HASH') {
            for my $r (@{ $d->{timers} || [] }) {
                my $t = norm($r) or next;
                push @timers, $t;
                $next_id = $t->{id} + 1 if $t->{id} >= $next_id;
            }
            $next_id = $d->{next_id} if defined $d->{next_id} && $d->{next_id} > $next_id;
        } else {
            warn "Could not read $DATA - starting with no timers.\n";
        }
    } else {
        my $n = migrate_legacy();
        if ($n) { print "Imported $n timer(s) from timers.db\n"; save(); }
    }
}

# ---------------------------------------------------------------- helpers

sub parse_int {
    my ($v) = @_;
    return undef if !defined $v || ref $v;
    return undef unless $v =~ /^\s*[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?\s*$/;
    return int($v);
}

sub in_list {
    my ($v, @list) = @_;
    return 0 if !defined $v || ref $v;
    for my $x (@list) { return 1 if $x eq $v; }
    return 0;
}

sub json_reply { my ($status, $data) = @_; return ($status, 'application/json', $JSON->encode($data)); }
sub err        { my ($status, $msg) = @_; return json_reply($status, { error => $msg }); }
sub forbid     { return err(403, 'Only the main computer can do that'); }

sub parse_body {
    my ($raw) = @_;
    $raw = '{}' unless defined $raw && length $raw;
    my $d = eval { $JSON->decode($raw) };
    return ref($d) eq 'HASH' ? $d : undef;
}

sub local_hostname {
    if ($^O eq 'darwin') {
        my $n = `/usr/sbin/scutil --get LocalHostName 2>/dev/null`;
        if (defined $n) { $n =~ s/^\s+|\s+$//g; return "$n.local" if length $n; }
    }
    return Sys::Hostname::hostname();
}

sub local_addresses {
    my @found;
    my $text = `/sbin/ifconfig 2>/dev/null` || `ifconfig 2>/dev/null` || '';
    while ($text =~ /\binet (\d+\.\d+\.\d+\.\d+)/g) {
        my $ip = $1;
        next if $ip =~ /^127\./;
        push @found, $ip unless grep { $_ eq $ip } @found;
    }
    return \@found;
}

# ---------------------------------------------------------------- routing

sub serve_static {
    my ($path, $local) = @_;
    my $rel = $path eq '/' ? 'index.html' : $path;
    $rel =~ s/%([0-9a-fA-F]{2})/chr(hex($1))/eg;
    $rel =~ s{^/+}{};
    return forbid() if !$local && !($rel eq 'output.html' || $rel =~ m{^fonts/});
    return err(404, 'Not found') if $rel =~ m{(?:^|/)\.\.(?:/|$)} || $rel =~ /\0/ || $rel =~ m{\\};
    my ($ext) = $rel =~ /(\.[^.\/]+)$/;
    my $ctype = defined $ext ? $STATIC_TYPES{lc $ext} : undef;
    my $file = "$ROOT/$rel";
    return err(404, 'Not found') unless defined $ctype && -f $file;
    my $data = do { local $/; open(my $fh, '<:raw', $file) or return err(404, 'Not found'); <$fh> };
    return (200, $ctype, $data);
}

sub find_timer {
    my ($id) = @_;
    return undef unless defined $id;
    for my $t (@timers) { return $t if $t->{id} == $id; }
    return undef;
}

sub route {
    my ($method, $path, $rawbody, $local) = @_;

    if ($method eq 'GET') {
        if ($path eq '/api/network') {
            return forbid() unless $local;
            return json_reply(200, { hostname => local_hostname(), addresses => local_addresses(), port => 0 + $PORT });
        }
        if ($path eq '/api/timers') {
            return forbid() unless $local;
            return json_reply(200, [ map { out($_) } @timers ]);
        }
        if ($path eq '/api/live') {
            my $elapsed = $live{elapsed} + ($live{isRunning} ? Time::HiRes::time() - $live{stamp} : 0);
            return json_reply(200, { timer => $live{timer}, elapsed => 0 + $elapsed,
                                     isRunning => ($live{isRunning} ? JSON::PP::true : JSON::PP::false) });
        }
        return serve_static($path, $local);
    }

    return forbid() unless $local;

    if ($method eq 'POST') {
        my $body = parse_body($rawbody) or return err(400, 'Invalid JSON');

        if ($path eq '/api/live') {
            my $t = $body->{timer};
            $t = undef unless ref($t) eq 'HASH' && %$t;
            my $el = $body->{elapsed};
            $el = (defined $el && !ref $el && $el =~ /^\s*-?[\d.]+(?:[eE][+-]?\d+)?\s*$/) ? 0 + $el : 0;
            %live = (timer => $t, elapsed => $el, isRunning => ($body->{isRunning} ? 1 : 0),
                     stamp => Time::HiRes::time());
            return json_reply(200, { success => JSON::PP::true });
        }
        return err(404, 'Not found') unless $path eq '/api/timers';

        my $name = $body->{name};
        return err(400, 'Timer name is required')
            if !defined $name || ref $name || $name =~ /^\s*$/;
        $name =~ s/^\s+|\s+$//g;

        my $type = $body->{type}; $type = 'countdown' if !defined $type || (!ref $type && $type eq '');
        return err(400, 'Type must be one of: ' . join(', ', @TYPES)) unless in_list($type, @TYPES);

        my $duration = parse_int($body->{duration_seconds});
        my $minimum = ($type eq 'countup' || $type eq 'blank') ? 0 : 1;
        return err(400, "Duration must be at least $minimum second(s)")
            if !defined $duration || $duration < $minimum;

        my $position = $body->{position};
        return err(400, 'Position must be one of: ' . join(', ', @POSITIONS)) unless in_list($position, @POSITIONS);

        my $size = $body->{size}; $size = 'large' if !defined $size || (!ref $size && $size eq '');
        return err(400, 'Size must be one of: ' . join(', ', @SIZES)) unless in_list($size, @SIZES);

        my $colour = $body->{colour}; $colour = 'white' if !defined $colour || (!ref $colour && $colour eq '');
        return err(400, 'Colour must be one of: ' . join(', ', @COLOURS)) unless in_list($colour, @COLOURS);

        my $show_title = exists $body->{show_title} ? ($body->{show_title} ? 1 : 0) : 1;
        my $show_time  = $body->{show_current_time} ? 1 : 0;

        my $stamp = now_stamp();
        my $t = { id => $next_id++, name => $name, duration_seconds => $duration, type => $type,
                  position => $position, size => $size, colour => $colour, show_title => $show_title,
                  show_current_time => $show_time, created_at => $stamp, updated_at => $stamp };
        push @timers, $t;
        save();
        return json_reply(201, out($t));
    }

    if ($method eq 'PUT') {
        return err(404, 'Not found') unless $path =~ m{^/api/timers/([^/]*)$};
        my $id = parse_int($1);
        my $body = parse_body($rawbody) or return err(400, 'Invalid JSON');

        my %set;
        if (exists $body->{duration_seconds}) {
            my $d = parse_int($body->{duration_seconds});
            return err(400, 'Duration must be at least 1 second') if !defined $d || $d < 1;
            $set{duration_seconds} = $d;
        }
        if (exists $body->{show_title}) {
            $set{show_title} = $body->{show_title} ? 1 : 0;
        }
        return err(400, 'No fields to update') unless %set;

        my $t = find_timer($id) or return err(404, 'Timer not found');
        $t->{$_} = $set{$_} for keys %set;
        $t->{updated_at} = now_stamp();
        save();
        return json_reply(200, out($t));
    }

    if ($method eq 'DELETE') {
        return err(404, 'Not found') unless $path =~ m{^/api/timers/([^/]*)$};
        my $id = parse_int($1);
        my $t = find_timer($id) or return err(404, 'Timer not found');
        @timers = grep { $_ != $t } @timers;
        save();
        return json_reply(200, { success => JSON::PP::true, id => 0 + $id });
    }

    return err(404, 'Not found');
}

# ---------------------------------------------------------------- tiny HTTP server

my (%buf, %born);
my ($listen, $sel);

sub close_client {
    my ($fh) = @_;
    my $id = fileno($fh);
    $sel->remove($fh);
    if (defined $id) { delete $buf{$id}; delete $born{$id}; }
    close($fh);
}

sub write_all {
    my ($fh, $data) = @_;
    my $off = 0;
    my $deadline = Time::HiRes::time() + 5;
    while ($off < length $data) {
        my $n = syswrite($fh, $data, 65536, $off);
        if (defined $n) { $off += $n; next; }
        if ($!{EAGAIN} || $!{EWOULDBLOCK} || $!{EINTR}) {
            last if Time::HiRes::time() > $deadline;
            IO::Select->new($fh)->can_write(0.5);
            next;
        }
        last;
    }
}

sub respond {
    my ($fh, $status, $ctype, $body) = @_;
    my $head = "HTTP/1.1 $status " . ($REASON{$status} || 'OK') . "\r\n"
             . "Content-Type: $ctype\r\nContent-Length: " . length($body) . "\r\n"
             . "Cache-Control: no-store\r\nConnection: close\r\n\r\n";
    write_all($fh, $head . $body);
    close_client($fh);
}

sub is_local_client {
    my ($fh) = @_;
    my $peer = $fh->peerhost;
    return 0 unless defined $peer;
    return 1 if $peer =~ /^127\./ || $peer eq '::1';
    my $me = $fh->sockhost;
    return (defined $me && $peer eq $me) ? 1 : 0;   # this computer talking to its own network address
}

sub process {
    my ($fh) = @_;
    my $id = fileno($fh);
    my $b = $buf{$id};
    my $end = index($b, "\r\n\r\n");
    if ($end < 0) { close_client($fh) if length($b) > 65536; return; }

    my @lines = split /\r\n/, substr($b, 0, $end);
    my $reqline = shift @lines;
    my ($method, $target) = $reqline =~ m{^([A-Z]+)\s+(\S+)\s+HTTP/1\.[01]$};
    return respond($fh, 400, 'application/json', '{"error":"Bad request"}') unless defined $method;

    my $cl = 0;
    for my $l (@lines) { $cl = $1 if $l =~ /^content-length:\s*(\d+)/i; }
    return respond($fh, 400, 'application/json', '{"error":"Request too large"}') if $cl > 1_000_000;
    return if length($b) < $end + 4 + $cl;   # wait for the rest of the body

    my $body = substr($b, $end + 4, $cl);
    my ($path) = split /\?/, $target, 2;
    my @res = eval { route($method, $path, $body, is_local_client($fh)) };
    if ($@ || !@res) {
        print STDERR "Error handling $method $path: $@\n";
        @res = (500, 'application/json', '{"error":"Server error"}');
    }
    respond($fh, @res);
}

sub run {
    $SIG{PIPE} = 'IGNORE';
    $| = 1;
    load_timers();
    $listen = IO::Socket::INET->new(LocalAddr => $HOST, LocalPort => $PORT, Proto => 'tcp',
                                    Listen => 128, ReuseAddr => 1)
        or die "Cannot listen on port $PORT: $!\n";
    $sel = IO::Select->new($listen);
    print "ProPre2.0 Timer Server running on http://localhost:$PORT\n";
    print 'Second screens can open http://' . local_hostname() . ":$PORT/output.html\n" if $HOST ne '127.0.0.1';

    while (1) {
        for my $fh ($sel->can_read(1)) {
            if (fileno($fh) == fileno($listen)) {
                my $c = $listen->accept or next;
                $c->blocking(0);
                $sel->add($c);
                $buf{fileno $c} = '';
                $born{fileno $c} = Time::HiRes::time();
                next;
            }
            my $n = sysread($fh, my $chunk, 65536);
            if (!defined $n) {
                next if $!{EAGAIN} || $!{EWOULDBLOCK} || $!{EINTR};
                close_client($fh);
                next;
            }
            if ($n == 0) { close_client($fh); next; }
            $buf{fileno $fh} .= $chunk;
            process($fh);
        }
        # drop connections that never finished sending a request
        for my $fh ($sel->handles) {
            next if fileno($fh) == fileno($listen);
            close_client($fh) if Time::HiRes::time() - ($born{fileno $fh} || 0) > 10;
        }
    }
}

if (grep { $_ eq '--daemon' } @ARGV) {
    my $pid = fork();
    die "Cannot fork: $!\n" unless defined $pid;
    exit 0 if $pid;
    setsid();
    open(STDIN, '<', '/dev/null');
    open(STDOUT, '>>', "$ROOT/server.log");
    open(STDERR, '>&', \*STDOUT);
}
run();
