package Map::Map1000;
#
#  map code for risk
#

use Exporter;
@ISA = qw(Exporter);
use base Map;

my $map = {
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
          continent  => "Oceania",
          cardtype   => "calvary",
          borders    => [ qw( Western_Australia New_Guinea ) ],
       },
       Indonesia          => {
          continent  => "Oceania",
          cardtype   => "infantry",
          borders    => [ qw( Western_Australia New_Guinea Siam ) ],
       },
       New_Guinea         => {
          continent  => "Oceania",
          cardtype   => "calvary",
          borders    => [ qw( Western_Australia Eastern_Australia Indonesia ) ],
       },
       Western_Australia  => {
          continent  => "Oceania",
          cardtype   => "artillery",
          borders    => [ qw( Eastern_Australia Indonesia New_Guinea ) ],
       },
       Great_Britain      => {
          continent  => "Europe",
          cardtype   => "infantry",
          borders    => [ qw( Northern_Europe Scandinavia Western_Europe Iceland ) ],
       },
       Iceland            => {
          continent  => "Europe",
          cardtype   => "calvary",
          borders    => [ qw( Scandinavia Greenland Great_Britain ) ],
       },
       Northern_Europe    => {
          continent  => "Europe",
          cardtype   => "calvary",
          borders    => [ qw( Scandinavia Great_Britain Western_Europe Russia Southern_Europe ) ],
       },
       Scandinavia        => {
          continent  => "Europe",
          cardtype   => "infantry",
          borders    => [ qw( Great_Britain Russia Northern_Europe Iceland ) ],
       },
       Southern_Europe    => {
          continent  => "Europe",
          cardtype   => "infantry",
          borders    => [ qw( Northern_Europe Western_Europe North_Africa Middle_East Egypt Russia ) ],
       },
       Russia => {
          continent  => "Europe",
          cardtype   => "infantry",
          borders    => [ qw( Northern_Europe Scandinavia Afghanistan Ural Southern_Europe Middle_East ) ],
       },
       Western_Europe => {
          continent  => "Europe",
          cardtype   => "infantry",
          borders    => [ qw( Northern_Europe Southern_Europe Great_Britain North_Africa ) ],
       },
       Congo        => {
         continent  => "Africa",
          cardtype   => "artillery",
          borders    => [ qw( East_Africa North_Africa South_Africa ) ],
       },
       East_Africa => {
         continent  => "Africa",
          cardtype   => "infantry",
          borders    => [ qw( Middle_East South_Africa North_Africa Egypt Madagascar Congo ) ],
       },
       Egypt => {
         continent  => "Africa",
          cardtype   => "calvary",
          borders    => [ qw( North_Africa East_Africa Southern_Europe Middle_East ) ],
       },
       Madagascar => {
          continent  => "Africa",
          cardtype   => "calvary",
          borders    => [ qw( East_Africa South_Africa ) ],
       },
       North_Africa => {
         continent  => "Africa",
          cardtype   => "infantry",
          borders    => [ qw( Brazil Congo Western_Europe Egypt Southern_Europe East_Africa ) ],
       },
       South_Africa => {
         continent  => "Africa",
          cardtype   => "artillery",
          borders    => [ qw( East_Africa Congo Madagascar ) ],
       },
       Argentina => {
         continent  => "South_America",
          cardtype   => "infantry",
          borders    => [ qw( Peru Brazil ) ],
       },
       Brazil => {
         continent  => "South_America",
          cardtype   => "infantry",
          borders    => [ qw( North_Africa Argentina Peru Venezuela ) ],
       },
       Peru => {
         continent  => "South_America",
          cardtype   => "calvary",
          borders    => [ qw( Brazil Venezuela Argentina ) ],
       },
       Venezuela => {
         continent  => "South_America",
          cardtype   => "calvary",
          borders    => [ qw( Peru Brazil Central_America ) ],
       },
       Alaska => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Northwest_Territory Kamchatka Alberta ) ],
       },
       Alberta => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Western_United_States Alaska Northwest_Territory Ontario ) ],
       },
       Central_America => {
         continent  => "North_America",
          cardtype   => "infantry",
          borders    => [ qw( Venezuela Eastern_United_States Western_United_States ) ],
       },
       Eastern_United_States => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Central_America Western_United_States Ontario Quebec ) ],
       },
       Greenland => {
         continent  => "North_America",
          cardtype   => "calvary",
          borders    => [ qw( Ontario Quebec Northwest_Territory Iceland ) ],
       },
       Northwest_Territory => {
          continent  => "North_America",
          cardtype   => "calvary",
          borders    => [ qw( Alaska Greenland Alberta Ontario ) ],
       },
       Ontario => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Northwest_Territory Eastern_United_States Quebec Greenland Alberta Western_United_States ) ],
       },
       Quebec => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Eastern_United_States Greenland Ontario ) ],
       },
       Western_United_States => {
         continent  => "North_America",
          cardtype   => "artillery",
          borders    => [ qw( Central_America Eastern_United_States Ontario Alberta ) ],
       },
       Afghanistan => {
          continent  => "Asia",
          cardtype   => "infantry",
          borders    => [ qw( China Russia Middle_East India Ural ) ],
       },
       China => {
          continent  => "Asia",
          cardtype   => "artillery",
          borders    => [ qw( Mongolia Siam Ural Siberia Afghanistan India ) ],
       },
       India => {
          continent  => "Asia",
          cardtype   => "calvary",
          borders    => [ qw( China Afghanistan Middle_East Siam ) ],
       },
       Irkutsk => {
          continent  => "Asia",
          cardtype   => "artillery",
          borders    => [ qw( Kamchatka Siberia Mongolia Yakutsk ) ],
       },
       Japan => {
          continent  => "Asia",
          cardtype   => "calvary",
          borders    => [ qw( Kamchatka Mongolia ) ],
       },
       Kamchatka => {
          continent  => "Asia",
          cardtype   => "artillery",
          borders    => [ qw( Alaska Japan Mongolia Irkutsk Yakutsk ) ],
       },
       Middle_East => {
          continent  => "Asia",
          cardtype   => "artillery",
          borders    => [ qw( India East_Africa Egypt Southern_Europe Afghanistan Russia ) ],
       },
       Mongolia => {
          continent  => "Asia",
          cardtype   => "calvary",
          borders    => [ qw( China Japan Siberia Irkutsk Kamchatka ) ],
       },
       Siam => {
          continent  => "Asia",
          cardtype   => "calvary",
          borders    => [ qw( Indonesia China India ) ],
       },
       Siberia => {
          continent  => "Asia",
          cardtype   => "infantry",
          borders    => [ qw( China Mongolia Yakutsk Ural Irkutsk ) ],
       },
       Ural => {
          continent  => "Asia",
          cardtype   => "infantry",
          borders    => [ qw( Siberia Russia China Afghanistan ) ],
       },
       Yakutsk => {
          continent  => "Asia",
          cardtype   => "artillery",
          borders    => [ qw( Kamchatka Irkutsk Siberia ) ],
       },
    },
};

sub new { 
  return bless \$map;
}
  
