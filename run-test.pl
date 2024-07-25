#!/usr/bin/perl -0777 -s -wn
use strict;
use JSON::XS;
use Firefox::Marionette;
use Firefox::Marionette::Keys qw<:all>;
use Firefox::Marionette::Buttons qw<:all>;
use Time::HiRes qw<sleep>;
use List::Util qw<any all none first>;
use Test::More;
use lib './lib';
use GhostInspector::Data qw<weave>;
use File::Basename qw<basename>;

use Data::Printer;

our $ff;
our %vars = ();
our ($help, $ignoreViewPort);
BEGIN
{
    if ( 0 == @ARGV || $::help // 0 )
    {
        my $scriptname = basename($0);
        warn <<~"END";
        $scriptname [options] file [files...]

        OPTIONS
        -help               Show this help page
        -visible            Run tests with browser window visible.
        -ignoreViewPort     Use default window size (ignoring test presets).
        -starturl=url       Override starting url for tests.
        END
        exit;
    }
    note "Tests will run in Firefox regardless of test settings.";
    if ( $ignoreViewPort )
    {
        $ff = Firefox::Marionette->new(visible => $::visible // 0);
    }
}

################
#### CONFIG ####
################
my $step_pause = 0.25;  # between steps
my $test_pause = 1;     # between tests

my $defaultViewPort = { width => 1280, height => 800 };
my $scrollOpts = {   behavior => 'instant'
                 ,   block => 'center'
                 ,   inline => 'center'
                 };

my @step_keys        = qw< command condition target value variableName optional notes extra >;
my @interact_cmds    = qw< click type assign keypress extract >;
my @assert_elem_cmds = qw< assertElementPresent assertElementNotPresent
                           assertElementVisible assertElementNotVisible
                           assertTextPresent assertTextNotPresent >;
my @other_cmds       = qw< open refresh goBack assertEval store extractEval eval pause exit >;
my @all_cmds         = (@interact_cmds, @assert_elem_cmds, @other_cmds);


###################
#### LOAD TEST ####
###################
my $test = decode_json($_) or die "Invalid json\n";

my $startUrl = $test->{startUrl}     // die "Missing starting url\n";
my $name     = $test->{name}         // die "Nameless test\n";
my $steps    = $test->{steps}        // die "No steps in test suite\n";
my $viewPort = $test->{viewportSize};

$startUrl = $::startUrl if defined $::startUrl; # override start url

defined $viewPort->{width} && defined $viewPort->{height}
    or $viewPort = $defaultViewPort;


##################
#### RUN TEST ####
##################
note sprintf "Starting test: %s", $name;

if ( $ignoreViewPort )
{
    # attempt to change viewport, but carry on either way
    $ff->resize($viewPort->{width}, $viewPort->{height})
        or diag "Could not resize browser window";
}
else
{
    # make new window to ensure we get the right viewport
    $ff = Firefox::Marionette->new(  visible  => $::visible // 0
                                  ,  width    => $viewPort->{width}
                                  ,  height   => $viewPort->{height}
                                  );
}
ok $ff->go($startUrl), "Could go to $startUrl";

$vars{'result.startUrl'} = $startUrl;

sleep $test_pause;
for my $idx (keys @{$steps})
{
    my $step = $steps->[$idx];
    sleep $step_pause;
    1 until $ff->interactive; # wait for firefox to load

    my ($cmd, $cond, $target, $val, $var, $optional, $notes, $extra) = @{$step}{@step_keys};
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

    $val = weave($val, %vars);

    if ( grep { $_ eq $cmd } @other_cmds )
    {
        $ff->refresh                    if $cmd eq 'refresh';
        $ff->goBack                     if $cmd eq 'goBack';
        ok 'passing' eq $val and last   if $cmd eq 'exit';
        note($desc), sleep $val/1000    if $cmd eq 'pause';
        $ff->script($val)               if $cmd eq 'eval';
        ok $ff->script($val), $desc     if $cmd eq 'assertEval';
        $vars{$var} = $ff->script($val) if $cmd eq 'extractEval';
        $vars{$var} = $val              if $cmd eq 'store';
        $ff->go($val)                   if $cmd eq 'open';
        next;
    }


    my @elems = find_elements($ff, $target);
    if ( grep { $_ eq $cmd } @interact_cmds )
    {
        unless( @elems )
        {
            diag "$desc\nCould not find $target";
            next;
        }
        $vars{$var} = elem_text($elems[0]) if $cmd eq 'extract';

        if( $cmd eq 'keypress' )
       {
            my @actions = ();
            click_element($ff, @elems); #click to select element :/
            push @actions, $ff->key_down(SHIFT())   if $extra->{shift};
            push @actions, $ff->key_down(CONTROL()) if $extra->{control};
            push @actions, $ff->key_down(ALT())     if $extra->{alt};
            push @actions, $ff->key_down(key_lookup($val));
            ok $ff->perform(@actions)->release();
            next;
        }

        ok $elems[0]->scroll($scrollOpts);

        ok click_element($ff, @elems), $desc                    if $cmd eq 'click';
        ok $elems[0]->type($val), $desc                         if $cmd eq 'type';
        ok $ff->script(<<~JS, args => [$elems[0], $val]), $desc if $cmd eq 'assign';
        if( !arguments[0].hasAttribute('value') )
            return 0;
        arguments[0].value = arguments[1];
        return 1;
        JS
        $ff->mouse_move($elems[0])           if $cmd eq 'mouseOver';
    }

    ok +(all  { defined                 } @elems), $desc if $cmd eq 'assertElementPresent';
    ok +(none { defined                 } @elems), $desc if $cmd eq 'assertElementNotPresent';
    ok +(all  { $_->is_displayed        } @elems), $desc if $cmd eq 'assertElementVisible';
    ok +(none { $_->is_displayed        } @elems), $desc if $cmd eq 'assertElementNotVisible';
    ok +(any  { elem_text($_) eq $val   } @elems), $desc if $cmd eq 'assertText';
    ok +(none { elem_text($_) eq $val   } @elems), $desc if $cmd eq 'assertNotText';
    ok +(any  { elem_contains($_, $val) } @elems), $desc if $cmd eq 'assertTextPresent';
    ok +(none { elem_contains($_, $val) } @elems), $desc if $cmd eq 'assertTextNotPresent';
}

$ff->clear_cache;

END
{
    done_testing;
}


###################
### SUBROUTINES ###
###################

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

sub elem_text
{
    my ($elem) = @_;
    if( $elem->tag_name eq 'input' )
    {
        return $elem->property('value');
    }
    $elem->text;
}

sub elem_contains
{
    my ($elem, $text) = @_;
    elem_text($elem) =~ qr/$text/;
}

sub key_lookup
{
    my ($key) = @_;
    return chr($key) if $key =~ /^\d+$/; #ascii code

    my %keys = (    left    => LEFT_BUTTON()
               ,    right   => RIGHT_BUTTON()
               ,    down    => DOWN_BUTTON()
               ,    up      => UP_BUTTON()
               ,    home    => HOME()
               );
    $keys{$key};
}

