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
our ($help, $visible, $ignoreViewPort, $timeout);
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
        -timeout=x          Set timeout in seconds for assertions (default: 15)
        END
        exit;
    }
    note "Tests will run in Firefox regardless of test settings.";
    if ( $ignoreViewPort )
    {
        $ff = Firefox::Marionette->new(visible => $visible // 0);
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
my $element_timeout_max = $timeout // 15;

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

%vars = ();
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
    $target = [map { weave($_, %vars) } ('ARRAY' eq ref $target ? map $_->{selector}, @$target
                                                                : $target)];

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
        $vars{$var} = elem_text($ff, $elems[0]) if $cmd eq 'extract';

        if( $cmd eq 'keypress' )
       {
            my @actions = ();
            click_element($ff, $elems[0]); #click to select element :/
            push @actions, $ff->key_down(SHIFT())   if $extra->{shift};
            push @actions, $ff->key_down(CONTROL()) if $extra->{control};
            push @actions, $ff->key_down(ALT())     if $extra->{alt};
            push @actions, $ff->key_down(key_lookup($val));
            ok $ff->perform(@actions)->release();
            next;
        }

        ok scroll_element($ff, $elems[0]), "Could scroll element into view";

        ok click_element($ff, $elems[0]), $desc         if $cmd eq 'click';
        ok type_element($ff, $elems[0], $val), $desc    if $cmd eq 'type';
        ok assign_element($ff, $elems[0], $val), $desc  if $cmd eq 'assign';
        #$ff->mouse_move($elems[0])                  if $cmd eq 'mouseOver';
    }

    next unless 'assert' eq substr $cmd, 0, 6;
    my $assert_ok = 0;
    for(0..$element_timeout_max)
    {
        $assert_ok = (@elems && all  { defined                      } @elems) if $cmd eq 'assertElementPresent';
        $assert_ok = (          none { defined                      } @elems) if $cmd eq 'assertElementNotPresent';
        $assert_ok = (@elems && all  { elem_displayed($ff, $_)      } @elems) if $cmd eq 'assertElementVisible';
        $assert_ok = (          none { elem_displayed($ff, $_)      } @elems) if $cmd eq 'assertElementNotVisible';
        $assert_ok = (@elems && any  { elem_text($ff, $_) eq $val   } @elems) if $cmd eq 'assertText';
        $assert_ok = (          none { elem_text($ff, $_) eq $val   } @elems) if $cmd eq 'assertNotText';
        $assert_ok = (@elems && any  { elem_contains($ff, $_, $val) } @elems) if $cmd eq 'assertTextPresent';
        $assert_ok = (          none { elem_contains($ff, $_, $val) } @elems) if $cmd eq 'assertTextNotPresent';
        last if $assert_ok;
        @elems = find_elements($ff, $target);
        sleep 1;
    }
    ok $assert_ok, $desc;
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
    my @found_elements;
    foreach my $selector (@$target)
    {
        my $is_xpath = 0 <= index $selector, '//';
        print $selector if $is_xpath;
        push @found_elements, [$_, undef] for $is_xpath ? $ff->find($selector)
                                                        : $ff->find_selector($selector);
        my @parts = $is_xpath ? split_unbracketed($selector, '\s')
                              : split_unquoted($selector, '\s');
        foreach my $idx (keys @parts)
        {
            my $partial = join' ', @parts[0..$idx];
            next if grep { $_ eq substr $partial, -1 } qw{ > + ~ };
            my $element = $is_xpath ? $ff->has($partial)
                                    : $ff->has_selector($partial);
            last unless $element;

            next unless 'iframe' eq $element->tag_name && $idx < $#parts;
            my @iframes = $is_xpath ? $ff->find($partial)
                                    : $ff->find_selector($partial);
            foreach my $iframe ( @iframes )
            {
                $ff->switch_to_frame($iframe);
                my @frame_elements = $is_xpath ? $ff->find(join' ', @parts[$idx+1 .. $#parts])
                                               : $ff->find_selector(join' ', @parts[$idx+1 .. $#parts]);
                push @found_elements, [$_, $iframe] for @frame_elements;
            }
            $ff->switch_to_parent_frame;
            last;
        }
    }
    @found_elements;
}


sub type_element
{
    my ($ff, $element, $val) = @_;
    $ff->switch_to_frame($element->[1]) if $element->[1];
    my $could_type = $element->[0]->type($val);
    $ff->switch_to_parent_frame;
    $could_type;
}


sub assign_element
{
    my ($ff, $element, $val) = @_;
    $ff->switch_to_frame($element->[1]) if $element->[1];
    $element->[0]->clear;
    my $could_assign = $element->[0]->type($val);
    $ff->switch_to_parent_frame;
    $could_assign;
}


sub scroll_element
{
    my ($ff, $element) = @_;
    for(0..$element_timeout_max)
    {
        last if elem_displayed($ff, $element);
        sleep 1;
    }
    $ff->switch_to_frame($element->[1]) if $element->[1];
    my $could_scroll = $element->[0]->scroll($scrollOpts);
    $ff->switch_to_parent_frame;
    $could_scroll;
}

# weird bug when clicking links without direct text-node descendants and a leading # in href
sub click_element
{
    my ($ff, $element) = @_;
    $ff->switch_to_frame($element->[1]) if $element->[1];
    eval
    {
        $element->[0]->click()
    };
    if ( ! $@ )
    {
        $ff->switch_to_parent_frame;
        return 1;
    }

    $ff->scroll($element->[0], $scrollOpts);
    my $clicked = $ff->script(<<~JS, args => [$element->[0]]);
        if( arguments[0].click ){
            arguments[0].click();
            return 1
        }
        return 0
        JS
    $ff->switch_to_parent_frame;
    $clicked;
}

sub elem_text
{
    my ($ff, $element) = @_;
    $ff->switch_to_frame($element->[1]) if $element->[1];
    if( $element->[0]->tag_name eq 'input' )
    {
        return $element->[0]->property('value');
    }
    my $element_text = $element->[0]->text;
    $ff->switch_to_parent_frame;
    $element_text;
}

sub elem_contains
{
    my ($ff, $element, $text) = @_;
    elem_text($ff, $element) =~ qr/$text/;
}

sub elem_displayed
{
    my ($ff, $element) = @_;
    $ff->switch_to_frame($element->[1]) if $element->[1];
    my $is_displayed = $element->[0]->is_displayed;
    $ff->switch_to_parent_frame;
    $is_displayed;
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

sub split_unquoted
{
    my ($string, $char) = @_;
    my @parts = split/($char*([\'\"])[^\2]*?\2)/, $string;
    split_preserve($char, @parts);
}

sub split_unbracketed
{
    my ($string, $char) = @_;
    my @parts = split/$char*\[[^\]]*?\]/, $string;
    split_preserve($char, @parts);
}

sub split_preserve
{
    my ($char, @parts) = @_;
    my @result = ('');
    my $join = 0;
    for my $idx (keys @parts)
    {
        my $part = $parts[$idx];
        if ( grep { $_ eq substr $part, -1 } qw< ' " > )
        {
            if ( 1 < length $part )
            {
                push @result, $part if ' ' eq substr $part, 0, 1;
                $result[-1].= $part if ' ' ne substr $part, 0, 1;
            }
            $join = 1;
            next;
        }
        my @split = split/$char+/, $part;
        if ( $join )
        {
            $result[-1].= shift @split;
            $join = 0;
        }
        push @result, @split;
    }
    grep { length } @result;
}
