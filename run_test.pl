#!/usr/bin/perl -0777 -s -wn
use strict;
use JSON::XS;
use Firefox::Marionette;
use Time::HiRes qw<sleep>;
use List::Util qw<any all none first>;
use Test::More;

use Data::Printer;

BEGIN
{
    note "Tests will run in Firefox regardless of settings.";
    $::visible //= 0;
    our $ff = Firefox::Marionette->new(visible => $::visible);
}

################
#### CONFIG ####
################
my $step_pause = 0.4;  # between steps
my $test_pause = 1;     # between tests

my $defaultViewPort = { width => 1280, height => 800 };
my $scrollOpts = {   behavior => 'instant'
                 ,   block => 'center'
                 ,   inline => 'center'
                 };

my @step_keys = qw<command condition target value variableName optional notes>;
my @interact_cmds = qw<click type>;
my @assert_elem_cmds = qw<assertElementPresent assertElementNotPresent assertElementVisible assertElementNotVisible assertTextPresent>;
my @other_cmds = qw<open assertEval extractEval pause>;
my @all_cmds = (@interact_cmds, @assert_elem_cmds, @other_cmds);


###################
#### LOAD TEST ####
###################
my $test = decode_json($_) or die "Invalid json\n";

my $startUrl = $test->{startUrl}     // die "Missing starting url\n";
my $name     = $test->{name}         // die "Nameless test\n";
my $steps    = $test->{steps}        // die "No steps in test suite\n";
my $viewPort = $test->{viewportSize};

defined $viewPort->{width} && defined $viewPort->{height}
    or $viewPort = $defaultViewPort;


##################
#### RUN TEST ####
##################
note sprintf "Starting test: %s", $name;

our %vars = ();
our $ff->resize($viewPort->{width}, $viewPort->{height})
    or diag "Could not resize browser window";
ok $ff->go($startUrl), "Could go to $startUrl";

$vars{'result.startUrl'} = $startUrl;

sleep $test_pause;
for my $idx (keys @{$steps})
{
    my $step = $steps->[$idx];
    sleep $step_pause;
    1 until $ff->interactive; # wait for firefox to load

    my ($cmd, $cond, $target, $val, $var, $optional, $notes) = @{$step}{@step_keys};
    my $desc = sprintf "%d: %s", $idx, $cmd;

    unless ( grep { $_ eq $cmd } @all_cmds )
    {
        diag "$desc\nUnimplemented command";
        next;
    }

    unless ( passes_condition($ff, $cond) )
    {
        diag "$desc\nCondition not met, skipping step";
        next;
    }

    $val //= '';
    $val =~ s/\{\{$_\}\}/$vars{$_}/g for keys %vars;

    if ( grep { $_ eq $cmd } @other_cmds )
    {
        note($desc), sleep $val/1000    if $cmd eq 'pause';
        ok $ff->script($val), $desc     if $cmd eq 'assertEval';
        $vars{$var} = $ff->script($val) if $cmd eq 'extractEval';
        $ff->go($val) if $cmd eq 'open';
        next;
    }


    if ( $idx == 24 )
    {
        p $target;
        $target =~ s/\"/\'/g;
        p $target;
    }
    my @elems = find_elements($ff, $target);
    p @elems if $idx == 24;
    sleep if $idx == 24;
    if ( grep { $_ eq $cmd } @interact_cmds )
    {
        unless( @elems )
        {
            diag "$desc\nCould not find $target";
            next;
        }
        ok $elems[0]->scroll($scrollOpts);

        ok click_element($ff, @elems), $desc if $cmd eq 'click';
        ok $elems[0]->type($val), $desc      if $cmd eq 'type';
        next;
    }

    ok +(all  { defined                 } @elems), $desc if $cmd eq 'assertElementPresent';
    ok +(none { defined                 } @elems), $desc if $cmd eq 'assertElementNotPresent';
    ok +(all  { $_->is_displayed        } @elems), $desc if $cmd eq 'assertElementVisible';
    ok +(none { $_->is_displayed        } @elems), $desc if $cmd eq 'assertElementNotVisible';
    ok +(any  { elem_contains($_, $val) } @elems), $desc if $cmd eq 'assertTextPresent';
}

$ff->clear_cache;

END
{
    done_testing;
}


sub passes_condition
{
    my ($ff, $cond) = @_;
    return 1 unless defined $cond;
    my $statement = $cond->{statement};
    $statement =~ s/\{\{$_\}\}/$vars{$_}/g for keys %vars;
    return $ff->script("$statement");
}


sub find_elements
{
    my ($ff, $target) = @_;
    my @selectors = ('ARRAY' eq ref $target ? map $_->{selector}, @$target
                                            : $target);
    my $css = first { $ff->has_selector($_) }
              grep { 0 > index $_, "//" }
              @selectors;
    my $xpath = first { $ff->has($_) }
                map { s/^xpath=//r }
                grep { 0 <= index $_, "//" }
                @selectors;
    return $ff->find_selector($css) if defined $css;
    return $ff->find($xpath)        if defined $xpath;
    return;
}

# weird bug when clicking links without direct text-node descendants and a leading # in href
sub click_element
{
    my ($ff, $elem) = @_;
    eval
    {
        $elem->click()
    };
    return 1 unless $@;

    $ff->scroll($elem, $scrollOpts);
    return $ff->script(<<~JS, args => [$elem]);
        if( arguments[0].click ){
            arguments[0].click();
            return 1
        }
        return 0
        JS
}

sub elem_contains
{
    my ($elem, $text) = @_;
    my $re = qr/$text/;
    if( $elem->tag_name eq 'input' )
    {
        return $elem->property('value') =~ $re;
    }
    $elem->text =~ $re;
}
