package Acme::CPANModulesUtil::FeatureMatrix;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

our %SPEC;

use Exporter qw(import);
our @EXPORT_OK = qw(draw_feature_matrix);

$SPEC{draw_feature_matrix} = {
    v => 1.1,
    summary => 'Draw features matrix of modules in an Acme::CPANModules::* list',
    args => {
        cpanmodule => {
            summary => 'Name of Acme::CPANModules::* module, without the prefix',
            schema => 'perl::modname*',
            req => 1,
            pos => 0,
            'x.completion' => ['perl_modname' => {ns_prefix=>'Acme::CPANModules'}],
        },
    },
};
sub draw_feature_matrix {
    require Markdown::To::POD;
    require Text::Table::Any;

    my %args = @_;

    my $list;
    my $mod;

    if ($args{_list}) {
        $list = $args{_list};
    } else {
        $mod = $args{cpanmodule} or return [400, "Please specify cpanmodule"];
        $mod = "Acme::CPANModules::$mod" unless $mod =~ /\AAcme::CPANModules::/;
        (my $mod_pm = "$mod.pm") =~ s!::!/!g;
        require $mod_pm;

        $list = ${"$mod\::LIST"};
    }

    # collect all features mentioned
    my @features;
    for my $e (@{ $list->{entries} }) {
        next unless $e->{features};
        for my $fname (sort keys %{$e->{features}}) {
            push @features, $fname unless grep {$_ eq $fname} @features;
        }
    }

    return [412, "No features mentioned in " . ($mod // "list")]
        unless @features;

    # generate table and collect notes
    my @notes;
    my $note_num = 0;
    my @rows;

  HEADER_ROW:
    {
        my @header_row = ("module");
        for my $fname (@features) {
            my $has_note;
            if ($list->{entry_features} && $list->{entry_features}{$fname} &&
                    $list->{entry_features}{$fname}{summary}) {
                $has_note++;
                $note_num++;
                my $note = "=item $note_num. $fname: " . $list->{entry_features}{$fname}{summary} . "\n\n";
                if ($list->{entry_features}{$fname}{description}) {
                    $note .= Markdown::To::POD::markdown_to_pod($list->{entry_features}{$fname}{description}) . "\n\n";
                }
                push @notes, $note;
            }
            push @header_row, "$fname" . ($has_note ? " *$note_num)" : "");
        }
        push @rows, \@header_row;
    }

  DATA_ROW:
    {
        for my $e (@{ $list->{entries} }) {
            my @row = ($e->{module});
            for my $fname (@features) {
                my $f;
                if (!$e->{features} || !defined($f = $e->{features}{$fname})) {
                    push @row, "N/A";
                    next;
                }
                if (!ref $f) {
                    push @row, $f ? "yes" : "no";
                    next;
                }
                my $fv = defined($f->{value}) ? ($f->{value} ? "yes" : "no") : "N/A";
                my $has_note;
                if ($f->{summary}) {
                    $has_note++;
                    $note_num++;
                    my $note = "=item $note_num. $f->{summary}\n\n";
                    if ($f->{description}) {
                        $note .= Markdown::To::POD::markdown_to_pod($f->{description}) . "\n\n";
                    }
                    push @notes, $note;
                }
                push @row, $fv . ($has_note ? " *$note_num)" : "");
            }
            push @rows, \@row;
        }
    }

    my $res = Text::Table::Any::table(
        rows => \@rows,
        header_row => 1,
    ); $res =~ s/^/ /gm;

    if (@notes) {
        $res .= join(
            "",
            "\n\nNotes:\n\n=over\n\n", @notes, "=back\n\n",
        );
    }

    [200, "OK", $res];
}

1;
# ABSTRACT:

=head1 SEE ALSO

C<Acme::CPANModules>
