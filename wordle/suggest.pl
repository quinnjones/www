#!/bin/env perl

use Mojolicious::Lite -signatures;

use constant DICTIONARY => '/usr/share/myspell/en_US.dic';

app->config( hypnotoad => { listen => [ 'http://*:3001' ],
                            proxy  => 1,
                          }
           );

if ( my $path = $ENV{MOJO_REVERSE_PROXY} ) {
    my @path_parts = grep /\S/, split m{/}, $path;

    app->hook( before_dispatch => sub {
        my ( $c ) = @_;
        my $url = $c->req->url;
        my $base = $url->base;
        push @{ $base->path }, @path_parts;
        $base->path->trailing_slash(1);
        $url->path->leading_slash(0);
    } );
}

get '/' => { words => [], error_msg => '' } => sub ( $c )
{
    $c->render( template => 'index' );
};

get 'index' => { words => [], error_msg => '' } => sub ( $c )
{
    $c->render( template => 'index' );
};

post 'index' => sub ( $c )
{
    # TODO: check incoming regex for anything out of the ordinary to
    # guard against DoS using "bad" regexes

    my $v = $c->validation;

    $v->optional( 'regex' )->like( qr/^\^?[\w.]{0,5}\$?$/ );
    $v->optional( 'contains' )->like( qr/^\w{0,5}$/ );

    if ( $v->has_error )
    {
        $c->stash( error_msg => 'One or more fields contain disallowed characters',
                   words     => [],
                 );
        return $c->render( 'index' );
    }

    my $matches = qr/@{[ $c->param( 'regex' ) ]}/;

    my @contains = map { qr/$_/ }
                   split //, $c->param( 'contains' );

    #$c->app->log->debug( "\$matches: $matches" );
    #$c->app->log->debug( "\@contains: @contains" );

    open( my $dic, '<', DICTIONARY ) or die $!;

    my %seen;

    WORD:
    while (<$dic>)
    {
        chomp;

        my ( $word ) = map { lc }
                       split /\//;

        next WORD unless length $word == 5;
        next WORD if $word =~ /\d/;

        next WORD unless $word =~ $matches;

        foreach my $letter ( @contains )
        {
            next WORD unless $word =~ $letter;
        }

        $seen{ $word }++;
    }

    $c->stash( error_msg => '',
               words => [ sort keys %seen ],
             );
    return $c->render( template => 'index' );
};

app->start;
__DATA__

@@ index.html.ep
% title 'Wordle Helper';
% layout 'default';

<h1>Wordle Suggestions</h1>

<p>This application provides suggestions for solving <a href="https://www.nytimes.com/games/wordle/">Wordle</a>. It works best if you've already tried a few guesses and know several letters that appear in the word. The list of suggestions can be quite long otherwise.

%= form_for 'index' => ( method => 'POST' ) => begin
  <div style="width: 100%; clear:both;">
    <p><strong>Green</strong>
    <p>Use a simplified regular expression to describe the letters you know (green letters) (optional)<br>

    <div style="width: 100%; clear:both;">
      <div style="float:left; margin: 5px; padding: 5px;">
        <p><%= text_field 'regex' %>
      </div>

      <div style="float:left">
        <p><strong>Examples:</strong>

        <ul>
          <li><code>^..e</code> : you know the third letter from the beginning is 'e', but not the first two letters</li>
          <li><code>y$</code> : you know the last letter is 'y'</li>
        </ul>
      </div>
    </div>
  </div>

  <div style="width: 100%; clear:both">
    <p><strong>Yellow</strong>
    <p>List letters that you know the word contains, but you don't know where they go (yellow letters) (optional)<br>

    <div style="width: 100%; clear:both">
      <div style="float:left; margin: 5px; padding: 5px;">
        <p><%= text_field 'contains' %>
      </div>


      <div style="float:left">
        <p><strong>Examples:</strong>

        <ul>
          <li><code>asd</code>: you know the words contains the letters 'a', 's', and 'd', but you don't know their placement order their order.</li>
        </ul>
      </div>
    </div>
  </div>

  <div style="width: 100%; clear:both">
    <p>
      %= submit_button 'Help me cheat at Wordle'
    </p>
  </div>
% end

<div style="width: 100%; clear:both">
  <p>Suggestions are prepared using the US-English <a href="https://hunspell.github.io/">Hunspell</a> dictionary. There is no guarantee that this dictionary's contents match Wordle's dictionary.

  % if ( $error_msg ) {
    <p><strong>Error:</strong> <%= $error_msg %>
  % }

  % if ( @$words ) {
      <p>Suggested words:
      <ul>
      % foreach my $word ( @$words ) {
        <li><%= $word %></li>
      % }
      </ul>
  % }

  <p>
    %= link_to 'Start Over' => 'index'
  </p>
</div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>

