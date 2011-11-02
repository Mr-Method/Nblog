use strict;
use warnings;

package Nblog::Controller::ResetPass;
use Moose;
use MooseX::NonMoose;
use Plack::Response;
use String::Random 'random_regex';

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

use feature ':5.10'; 

extends 'WebNano::Controller';

sub find_user {
    my( $self, $name ) = @_;
    my $user = $self->app->schema->resultset( 'User' )->search({ username =>  $name })->next
       //
      $self->app->schema->resultset( 'User' )->search({ email => $name })->next;
    return $user, $user->email, $user->pass_token if $user;
    return;
}

sub wrap_text{
    my( $self, $text ) = @_;
    return $self->render( template => \$text );
}

sub update_user{
    my( $self, $user, $fields ) = @_;
    $user->update( $fields );
}

sub index_action {
   my ( $self ) = @_;
   my $req = $self->req;
   if( $req->method eq 'POST' ){
       my $username = $req->param( 'username' );
       my( $user, $email ) = $self->find_user( $username );
       if( !$user ){
           return $self->wrap_text( "User not found" );
       }
       else{
           $self->update_user( $user, { pass_token => random_regex( '\w{40}' ) });
           $self->send_pass_token( $user, $username, $email );
           return $self->wrap_text( "Email sent" );
       }
   }
   return $self->wrap_text( <<END );
<form method="POST">
Username or email: <input type="text" name="username">
<input type="submit">
</form>
END

}

sub build_email {
    my( $self, $to, $reset_url ) = @_;
    return Email::Simple->create(
      header => [
        To      => $to,
        From    => 'root@localhost',
        Subject => "Password reset",
      ],
      body => $reset_url,
    );
}


sub send_pass_token {
    my( $self, $user, $username, $email, $pass_token ) = @_;
    my $env = $self->env;
    my $my_server = $env->{HTTP_ORIGIN} //
    ( $env->{'psgi.url_scheme'} // 'http' ) . '://' . 
    ( $env->{HTTP_HOST} // 
        $env->{SERVER_NAME} . 
        ( $env->{SERVER_PORT} && $env->{SERVER_PORT} != 80 ? ':' . $env->{SERVER_PORT} : '' )
    );
    my $reset_url = $my_server . $self->self_url . 'reset/' . $username . '/' . $pass_token;
    sendmail( $self->build_email( $email, $reset_url ) );
}

sub reset_action {
    my ( $self, $name, $token ) = @_;
    my $req = $self->req;
    my( $user, $email, $pass_token ) = $self->find_user( $name );
    if( !( $user && $pass_token eq $token ) ){
        return 'Token invalid';
    }
    else{
        if( $req->method eq 'POST' ){
            $self->update_user( $user, { pass_token => undef, password => $req->param( 'password' ) } );
            return $self->wrap_text( 'Password reset' );
        }
        else{
            return $self->wrap_text( '<form method="POST">New password:<input type="text" name="password"><input type="submit"></form>' );
        }
    }
}


1;
