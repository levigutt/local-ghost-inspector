package GhostInspector::Data;
use strict;
use Carp;

our (@ISA, @EXPORT, @EXPORT_OK);
@EXPORT     = qw<>;
@EXPORT_OK  = qw<weave>;

sub weave;
require Exporter; @ISA = qw<Exporter>;

# dependencies
use Data::Fake  qw< Core Internet Text >;
use Data::Faker qw< Company DateTime Internet Name PhoneNumber StreetAddress >;
use Locale::Codes::Country;
use Data::GUID;

my $faker = Data::Faker->new();

#################
### CONSTANTS ###
#################
my $week_in_seconds = 60 * 60 * 24 * 7;
my $date_format     = "F MMM dd yyyy HH:mm:ss ZZZZ (VVVV)";
my $avatar_format   = 'https://cloudflare-ipfs.com/ipfs/Qmd3W5DuhgHirLHGVixi6V76LhCkZUz6pnFt5AJBiyvHye/avatar/%d.jpg'; # borrowed from [bchavez/Bogus](https://github.com/bchavez/Bogus)
my $max_avatars     = 1249;

############
### DATA ###
############
my @special_chars = split//, ',._!"#$%&/()=?\€<>;:\'';
my @country_codes = map { uc } all_country_codes();
my @alphanums = ('a'..'z', 'A'..'Z', 0..9);
my @months    = qw< January February March April May June July August September
                    October November December >;
my @weekdays  = qw< Monday Tuesday Wednesday Thursday Friday Saturday Sunday >;
my @opinions  = qw< Luxe Sleek Elegant Stylish Refreshing Bold Vibrant Chic
                    Timeless Exquisite >;
my @sizes     = qw< Tiny Small Medium Large Gigantic Petite Massive Miniature
                    Enormous Compact Long Tall Wide Narrow Slim Short >;
my @qualities = qw< Handcrafted Organic Innovative Premium Versatile Durable
                    High-performance Sustainable >;
my @shapes    = qw< Round Square Oval Rectangular Triangular Circular
                    Diamond-shaped Heart-shaped Hexagonal Octagonal >;
my @ages      = qw< Vintage Old-Fashioned Classic Retro Modern New Brand-New >;
my @colors    = qw< Red Blue Green Yellow Orange Purple Pink Brown Black White
                    Gray Gold Silver Turquoise Maroon >;
my @materials = qw< Wood Metal Plastic Glass Fabric Leather Ceramic Paper Stone
                    Rubber Concrete Clay Vinyl Silk Wool Cotton Linen Bamboo
                    Polyester Foam >;
my @items     = qw< Accessories Accessory Art Automotive Baby Beauty Book Boot
                    Clothes Cosmetics Decor Decorations Electronic Equipment
                    Fitness Food Footwear Furniture Game Games Garden Gardening
                    Gear Health Home Jewelry Magazine Office Outdoor Party Pet
                    Shoe Sport Stationery Supplies Tech Tool Toy Travel
                    Traveling Hunting Sporting Carving >;
my @suffixes = qw< Kit Set Pack Mix Collection >;

#################
#### PICKERS ####
#################
my $alphanum_picker = fake_pick(@alphanums);
my $opinion_picker  = fake_pick(@opinions);
my $size_picker     = fake_pick(@sizes);
my $quality_picker  = fake_pick(@qualities);
my $shape_picker    = fake_pick(@shapes);
my $age_picker      = fake_pick(@ages);
my $color_picker    = fake_pick(@colors);
my $material_picker = fake_pick(@materials);
my $item_picker     = fake_pick(@items);
my $suffix_picker   = fake_pick(@suffixes);
my $avatar_picker   = sub { sprintf $avatar_format, fake_int(0, $max_avatars)->() };

sub product_name
{
    my @words = map { rand > 0.75 ? $_->() : () }
                (   $opinion_picker
                ,   $quality_picker
                ,   $size_picker
                ,   $shape_picker
                ,   $age_picker
                ,   $color_picker
                ,   $material_picker
                );

    my $item = $item_picker->();
    push @words, $item;
    push @words, $suffix_picker->() if 1 == @words || 'ing' eq substr($item, -3);
    join " ", @words;
}

sub date_past
{
    my $dt = DateTime->new(epoch => rand(time-1));
    $dt->format_cldr($date_format);
}

sub date_recent
{
    my $dt = DateTime->new(epoch => time-rand($week_in_seconds));
    $dt->format_cldr($date_format);
}

sub date_future
{
    my $dt = DateTime->new(epoch => time+rand(time));
    $dt->format_cldr($date_format);
}

sub date_soon
{
    my $dt = DateTime->new(epoch => time+rand($week_in_seconds));
    $dt->format_cldr($date_format);
}

my %translations =  (   'timestamp'               => sub { substr join("",split/\./, time), 0, 13 }
                    ,   'alphanumeric'            => sub { join '', map { $alphanum_picker->() } 1..16 }
                    ,   'name.firstName'          => sub { $faker->first_name() }
                    ,   'name.lastName'           => sub { $faker->last_name() }
                    ,   'name.prefix'             => sub { $faker->name_prefix() }
                    ,   'name.suffix'             => sub { $faker->name_suffix() }
                    ,   'name.title'              => sub { $faker->job_title() }
                    ,   'company.companyName'     => sub { $faker->company() }
                    ,   'address.streetAddress'   => sub { $faker->street_address() }
                    ,   'address.city'            => sub { $faker->city() }
                    ,   'address.state'           => sub { $faker->us_state() }
                    ,   'address.stateAbbr'       => sub { $faker->us_state_abbr() }
                    ,   'address.zipCode'         => sub { $faker->us_zip_code() }
                    ,   'address.countryCode'     => fake_pick(@country_codes)
                    ,   'phone.phoneNumber'       => sub { $faker->phone_number() }
                    ,   'phone.phoneNumberFormat' => fake_digits('###-###-####')
                    ,   'image.avatar'            => sub { image_avatar() }
                    ,   'internet.email'          => fake_email()
                    ,   'internet.password'       => sub { join '', map { fake_pick(@alphanums, @special_chars)->() } 1..20 }
                    ,   'internet.ip'             => sub { $faker->ip_address() }
                    ,   'internet.color'          => sub { "#".join'', map { sprintf "%x", $_ }
                                                                       fake_array(3, fake_pick(0..255))->()->@*
                                                         }
                    ,   'date.month'              => fake_pick(@months)
                    ,   'date.weekday'            => fake_pick(@weekdays)
                    ,   'date.past'               => \&date_past
                    ,   'date.recent'             => \&date_recent
                    ,   'date.future'             => \&date_future
                    ,   'date.soon'               => \&date_soon
                    ,   'commerce.productName'    => \&product_name
                    ,   'commerce.price'          => sub { sprintf "%d.%02d", fake_int(1,9999)->(), fake_int(0,99)->() }
                    ,   'lorem.text'              => fake_paragraphs(1)
                    ,   'random.number'           => fake_int(1,99999)
                    ,   'random.uuid'             => sub { lc Data::GUID->new->as_string }
                    );

sub weave
{
    my ($value, %vars) = @_;
    $value //= '';
    $value =~ s/\{\{$_\}\}/$translations{$_}->()/ge for keys %translations;
    $value =~ s/\{\{$_\}\}/$vars{$_}/gx for keys %vars;
    $value;
}
