use strict;
use warnings;

package Nblog::Controller;

use base 'WebNano::Controller';

sub search_subcontrollers { 1 }

sub index_action {
    my $self = shift;
    my $articles = $self->app->schema->resultset('Nblog::Schema::Result::Article')->get_latest_articles();
    return $self->render( template => 'blog_index.tt', articles => $articles );
}

sub login_action {
    my $self = shift;
    my $env = $self->env;
    return $self->render( 
        template => 'login.tt',
        redir_to => $env->{'psgix.session'}{redir_to},
    );
}


sub archived_action {
    my ( $self, $year, $month, $day ) = @_;

    my $articles = $self->app->schema->resultset('Article')->archived( year => $year, month => $month, day => $day );
    return $self->render( 
        template => 'blog_index.tt',
        articles => $articles,
    );
}


sub search_action {
   my ( $self, $phrase ) = @_;

   if ( !defined $phrase )
   {
      $phrase = $self->req->param( 'phrase' );
   }

   my $articles = $self->app->schema->resultset('Article')->search(
      [
         subject => { like => "%$phrase%" },
         body    => { like => "%$phrase%" },
      ]
   );

   return $self->render( 
       template => 'blog_index.tt',
       articles => $articles,
   )
}

sub tag_action {
   my ( $self, $tag ) = @_;

   my $db_tag =
      $self->app->schema->resultset('Tag')
      ->search( { name => { like => $self->app->ravlog_url_to_query($tag) } } )->first();
   warn $db_tag->id;
   return $self->render(
       template => 'blog_index.tt',
       articles => scalar $db_tag->articles,
       rss      => $db_tag->name,
   );
}

sub page_action {  
   my ( $self, $what ) = @_;

   my $page =
       $self->app->schema->resultset('Page')
      ->search( { name => { like => $self->app->ravlog_url_to_query($what) } } )->first();

   my $name = $self->app->ravlog_txt_to_url( $page->name );
   my $sidebar = $page->display_sidebar();
   return $self->render( 
       template => 'page.tt',
       page => $page,
       title => $page->name,
       sidebar => $sidebar,
       activelink => { $name => 'activelink' },
   )
}


1;

