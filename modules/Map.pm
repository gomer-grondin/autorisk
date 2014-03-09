package Map;
#
#  map code for risk
#

use Exporter;
@ISA = qw(Exporter);

my $maps = {
   map1000 => {
     continents => {
         Asia          => 7,
         North_America => 5,
         South_America => 2,
         Africa        => 3,
         Europe        => 5,
         Oceania       => 2,
     },
     territories => {
         Eastern_Australia  => {
            rectangle  => [ 840, 400, 920, 480 ],
            continent  => "Oceania",
            cardtype   => "calvary",
            borders    => [ qw( Western_Australia New_Guinea ) ],
         },
         Indonesia          => {
            rectangle  => [ 760, 320, 840, 380 ],
            continent  => "Oceania",
            cardtype   => "infantry",
            borders    => [ qw( Western_Australia New_Guinea Siam ) ],
         },
         New_Guinea         => {
            rectangle  => [ 840, 320, 920, 400 ],
            continent  => "Oceania",
            cardtype   => "calvary",
            borders    => [ qw( Western_Australia Eastern_Australia Indonesia ) ],
         },
         Western_Australia  => {
            rectangle  => [ 760, 380, 840, 480 ],
            continent  => "Oceania",
            cardtype   => "artillery",
            borders    => [ qw( Eastern_Australia Indonesia New_Guinea ) ],
         },
         Great_Britain      => {
            rectangle  => [ 340, 160, 420, 220 ],
            continent  => "Europe",
            cardtype   => "infantry",
            borders    => [ qw( Northern_Europe Scandinavia Western_Europe Iceland ) ],
         },
         Iceland            => {
            rectangle  => [ 300, 100, 380, 160 ],
            continent  => "Europe",
            cardtype   => "calvary",
            borders    => [ qw( Scandinavia Greenland Great_Britain ) ],
         },
         Northern_Europe    => {
            rectangle  => [ 420, 160, 520, 220 ],
            continent  => "Europe",
            cardtype   => "calvary",
            borders    => [ qw( Scandinavia Great_Britain Western_Europe Russia Southern_Europe ) ],
         },
         Scandinavia        => {
            rectangle  => [ 380, 100, 520, 160 ],
            continent  => "Europe",
            cardtype   => "infantry",
            borders    => [ qw( Great_Britain Russia Northern_Europe Iceland ) ],
         },
         Southern_Europe    => {
            rectangle  => [ 440, 220, 520, 280 ],
            continent  => "Europe",
            cardtype   => "infantry",
            borders    => [ qw( Northern_Europe Western_Europe North_Africa Middle_East Egypt Russia ) ],
         },
         Russia => {
            rectangle  => [ 520, 120, 600, 260 ],
            continent  => "Europe",
            cardtype   => "infantry",
            borders    => [ qw( Northern_Europe Scandinavia Afghanistan Ural Southern_Europe Middle_East ) ],
         },
         Western_Europe => {
            rectangle  => [ 360, 220, 440, 280 ],
            continent  => "Europe",
            cardtype   => "infantry",
            borders    => [ qw( Northern_Europe Southern_Europe Great_Britain North_Africa ) ],
         },
         Congo        => {
           rectangle  => [ 340, 420, 460, 480 ],
           continent  => "Africa",
            cardtype   => "artillery",
            borders    => [ qw( East_Africa North_Africa South_Africa ) ],
         },
         East_Africa => {
           rectangle  => [ 460, 360, 520, 480 ],
           continent  => "Africa",
            cardtype   => "infantry",
            borders    => [ qw( Middle_East South_Africa North_Africa Egypt Madagascar Congo ) ],
         },
         Egypt => {
           rectangle  => [ 460, 280, 520, 360 ],
           continent  => "Africa",
            cardtype   => "calvary",
            borders    => [ qw( North_Africa East_Africa Southern_Europe Middle_East ) ],
         },
         Madagascar => {
           rectangle  => [ 520, 440, 600, 510 ],
            continent  => "Africa",
            cardtype   => "calvary",
            borders    => [ qw( East_Africa South_Africa ) ],
         },
         North_Africa => {
           rectangle  => [ 300, 280, 460, 420 ],
           continent  => "Africa",
            cardtype   => "infantry",
            borders    => [ qw( Brazil Congo Western_Europe Egypt Southern_Europe East_Africa ) ],
         },
         South_Africa => {
           rectangle  => [ 400, 480, 520, 540 ],
           continent  => "Africa",
            cardtype   => "artillery",
            borders    => [ qw( East_Africa Congo Madagascar ) ],
         },
         Argentina => {
           rectangle  => [ 100, 460, 220, 520 ],
           continent  => "South_America",
            cardtype   => "infantry",
            borders    => [ qw( Peru Brazil ) ],
         },
         Brazil => {
           rectangle  => [ 160, 400, 300, 460 ],
           continent  => "South_America",
            cardtype   => "infantry",
            borders    => [ qw( North_Africa Argentina Peru Venezuela ) ],
         },
         Peru => {
           rectangle  => [ 60, 400, 160, 460 ],
           continent  => "South_America",
            cardtype   => "calvary",
            borders    => [ qw( Brazil Venezuela Argentina ) ],
         },
         Venezuela => {
           rectangle  => [ 100, 340, 200, 400 ],
           continent  => "South_America",
            cardtype   => "calvary",
            borders    => [ qw( Peru Brazil Central_America ) ],
         },
         Alaska => {
           rectangle  => [ 20, 100, 100, 160 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Northwest_Territory Kamchatka Alberta ) ],
         },
         Alberta => {
           rectangle  => [ 30, 160, 120, 220 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Western_United_States Alaska Northwest_Territory Ontario ) ],
         },
         Central_America => {
           rectangle  => [ 100, 280, 200, 340 ],
           continent  => "North_America",
            cardtype   => "infantry",
            borders    => [ qw( Venezuela Eastern_United_States Western_United_States ) ],
         },
         Eastern_United_States => {
           rectangle  => [ 160, 220, 260, 280 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Central_America Western_United_States Ontario Quebec ) ],
         },
         Greenland => {
            rectangle  => [ 190, 100, 300, 160 ],
           continent  => "North_America",
            cardtype   => "calvary",
            borders    => [ qw( Ontario Quebec Northwest_Territory Iceland ) ],
         },
         Northwest_Territory => {
            rectangle  => [ 100, 100, 190, 160 ],
            continent  => "North_America",
            cardtype   => "calvary",
            borders    => [ qw( Alaska Greenland Alberta Ontario ) ],
         },
         Ontario => {
           rectangle  => [ 120, 160, 200, 220 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Northwest_Territory Eastern_United_States Quebec Greenland Alberta Western_United_States ) ],
         },
         Quebec => {
           rectangle  => [ 200, 160, 280, 220 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Eastern_United_States Greenland Ontario ) ],
         },
         Western_United_States => {
           rectangle  => [ 60, 220, 160, 280 ],
           continent  => "North_America",
            cardtype   => "artillery",
            borders    => [ qw( Central_America Eastern_United_States Ontario Alberta ) ],
         },
         Afghanistan => {
            rectangle  => [ 600, 200, 680, 260 ],
            continent  => "Asia",
            cardtype   => "infantry",
            borders    => [ qw( China Russia Middle_East India Ural ) ],
         },
         China => {
            rectangle  => [ 680, 180, 760, 260 ],
            continent  => "Asia",
            cardtype   => "artillery",
            borders    => [ qw( Mongolia Siam Ural Siberia Afghanistan India ) ],
         },
         India => {
            rectangle  => [ 620, 260, 760, 320 ],
            continent  => "Asia",
            cardtype   => "calvary",
            borders    => [ qw( China Afghanistan Middle_East Siam ) ],
         },
         Irkutsk => {
            rectangle  => [ 760, 120, 860, 160 ],
            continent  => "Asia",
            cardtype   => "artillery",
            borders    => [ qw( Kamchatka Siberia Mongolia Yakutsk ) ],
         },
         Japan => {
            rectangle  => [ 860, 180, 940, 240 ],
            continent  => "Asia",
            cardtype   => "calvary",
            borders    => [ qw( Kamchatka Mongolia ) ],
         },
         Kamchatka => {
            rectangle  => [ 860, 100, 940, 180 ],
            continent  => "Asia",
            cardtype   => "artillery",
            borders    => [ qw( Alaska Japan Mongolia Irkutsk Yakutsk ) ],
         },
         Middle_East => {
            rectangle  => [ 520, 260, 620, 400 ],
            continent  => "Asia",
            cardtype   => "artillery",
            borders    => [ qw( India East_Africa Egypt Southern_Europe Afghanistan Russia ) ],
         },
         Mongolia => {
            rectangle  => [ 760, 160, 860, 200 ],
            continent  => "Asia",
            cardtype   => "calvary",
            borders    => [ qw( China Japan Siberia Irkutsk Kamchatka ) ],
         },
         Siam => {
            rectangle  => [ 760, 240, 840, 320 ],
            continent  => "Asia",
            cardtype   => "calvary",
            borders    => [ qw( Indonesia China India ) ],
         },
         Siberia => {
            rectangle  => [ 680, 100, 760, 180 ],
            continent  => "Asia",
            cardtype   => "infantry",
            borders    => [ qw( China Mongolia Yakutsk Ural Irkutsk ) ],
         },
         Ural => {
            rectangle  => [ 600, 100, 680, 200 ],
            continent  => "Asia",
            cardtype   => "infantry",
            borders    => [ qw( Siberia Russia China Afghanistan ) ],
         },
         Yakutsk => {
            rectangle  => [ 760, 80, 860, 120 ],
            continent  => "Asia",
            cardtype   => "artillery",
            borders    => [ qw( Kamchatka Irkutsk Siberia ) ],
         },
      },
  },
};
  
sub new { 
  my( $self, $input ) = @_;
  my $m = $input->{mapid} or die "no map specified";
  exists $maps->{$m} or die " $m not defined in mapset ";
  return $maps->{$m};
}

