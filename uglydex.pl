use strictures 1;
use autodie;
use Text::Markdown 'markdown';
use File::Path 'make_path';
use File::Basename 'fileparse';

sub sentence {
    my (@parts) = @_;
    my $result = '';
    for my $i (0 .. $#parts) {
        if ($i != 0) {
            if ($i == $#parts) {
                $result .= ', and ';
            }
            else {
                $result .= ', ';
            }
        }
        $result .= $parts[$i];
    }
    return $result;
}

sub contributors {
    my ($path) = @_;
    my @contributors;
    my %known_contributors;
    say $path;
    open my $handle, '-|', qw(git log --format=%aN), $path;
    while (my $contributor = <$handle>) {
        chomp $contributor;
        if ($contributor ne 'SCMS' && !$known_contributors{$contributor}) {
            push @contributors, $contributor;
            $known_contributors{$contributor} = 1;
        }
    }
    return @contributors;
}

sub parse_set {
    my (%set) = @_;
    my $item = $set{item} ? " @ $set{item}" : q[];
    my $ability = $set{ability} ? "Ability: $set{ability}<br>" : q[];
    my $moves = join '<br>', map { "- $_" } grep { $_ } @{$set{moves}};
    my $evs = $set{evs} ? "EVs: $set{evs}<br>" : q[];
    my $nature = $set{nature} ? "$set{nature} Nature<br>" : q[];
    return <<HTML;
<div class=set>
    $set{pokemon}$item<br>
    $ability
    $evs
    $nature
    $moves
</div>
HTML
}

sub parse {
    my ($path) = @_;
    my ($pokemon) = $path =~ m{([^/]+?)\.txt$};
    open my $file_handle, '<', $path;
    my @lines = <$file_handle>;
    my %set;
    for my $line (@lines) {
        $line =~ s/^(=+)$/---/;
        $line =~ s/^(#+)$/===/;
        if (%set || $line =~ /^name:/i) {
            if (my ($elem, $value) = $line =~ /^(.+?):\s*(.*)$/) {
                if (my ($no) = $elem =~ /^move (\d)$/i) {
                    $set{moves}[$no - 1] = $value;
                }
                else {
                    $set{lc $elem} = $value;
                }
                $line = '';
                next;
            }
            $set{pokemon} = $pokemon;
            $line = parse_set(%set) . "\n\n";
            %set = ();
        }
    }
    return markdown join '', @lines;
}

sub parse_mons {
    chdir 'scms';
    my %mons;
    while (my $path = glob 'dex/analyses/xy/*/*.txt') {
        my ($tier, $pokemon) = $path =~ m{(\w+)/([^/]+)\.txt$};
        my $location = lc "/uglydex/$tier/$pokemon/index.html";
        $location =~ s/[. ]+(?!html)/-/g;
        push @{$mons{$pokemon}}, {
            path => $path,
            tier => $tier,
            location => $location,
        };
    }
    for my $pokemon (keys %mons) {
        for my $pokemon_descriptor (@{$mons{$pokemon}}) {
            my $path = $pokemon_descriptor->{path};
            my $tier = $pokemon_descriptor->{tier};
            my $lc_pokemon = lc $pokemon;
            my $parsed_doc = parse $path;
            my $tiers = join "", map { my $location = $_->{location}; $location =~ s/\/index\.html//; "<li><a href='$location'>$_->{tier}</a>" } @{$mons{$pokemon}};
            my $html = <<HTML;
<!DOCTYPE html>
<meta charset=utf-8>
<title>$pokemon in $tier</title>
<link rel=stylesheet href="/uglydex/style.css">
<img src="http://www.smogon.com/dex/media/sprites/xy/$lc_pokemon.gif" class="sprite">
<ul class=nav>
<li><a href="/uglydex/">Home</a>
<li><a>Tiers</a>
<ul>
$tiers
</ul>
</ul>
$parsed_doc
<hr><p><small>Entries are created by <a href="http://www.smogon.com/credits">Smogon
University contributors</a>. This site is only intended to show parts of analysis
that are hidden by official CMS. Analysis is available at <a href="http://www.smogon.com/dex/xy/pokemon/$lc_pokemon">
http://www.smogon.com/dex/xy/pokemon/$lc_pokemon</a>.</small>
HTML
            my $location = "..$pokemon_descriptor->{location}";
            my $directory_path = (fileparse $location)[1];
            make_path $directory_path;
            open my $write, '>', $location;
            print $write $html;
        }
    }
    chdir '..';
}

sub parse_dirs {
    while (my $directory_location = glob 'uglydex/*/') {
        opendir(my $directory, $directory_location);
        my ($tier) = $directory_location =~ m{uglydex/(.+)/};
        my $mons = join '', map { my $name = ucfirst; "<li><a href='/uglydex/$tier/$_'>$name</a>" } grep { !/\./ } sort readdir $directory;
        my $html = <<"HTML";
<!DOCTYPE html>
<meta charset=utf-8>
<title>$tier</title>
<link rel=stylesheet href="/uglydex/style.css">
<ul>
$mons
</ul>
HTML
        open my $descriptor, '>', "${directory_location}index.html";
        print $descriptor $html;
    }
}

sub main {
    parse_mons;
    parse_dirs;
}

main;
