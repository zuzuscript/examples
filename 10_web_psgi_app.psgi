use utf8;
use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../lib";

use Plack::Builder;
use Zuzu::Web::PSGI;

my $app = Zuzu::Web::PSGI->app(
	script => "$Bin/10_web_psgi_app.zzs",
	lib => [ "$Bin/../modules" ],
);

builder {
	enable 'ContentLength';
	$app;
};
