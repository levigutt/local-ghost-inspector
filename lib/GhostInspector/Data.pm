package GhostInspector::Data;
use strict;
use Carp;

our (@ISA, @EXPORT, @EXPORT_OK);
@EXPORT     = qw<>;
@EXPORT_OK  = qw<weave>;

sub weave;
require Exporter; @ISA = qw<Exporter>;

# dependencies
use Data::Fake qw<Core Internet Text>;
use Data::Faker qw<Company DateTime Internet Name PhoneNumber StreetAddress>;
use Locale::Codes::Country;
use Data::GUID;

my $faker = Data::Faker->new();

my @months   = qw< January February March April May June July August September October November December >;
my @weekdays = qw< Monday Tuesday Wednesday Thursday Friday Saturday Sunday >;
my @alphanums = ('a'..'z', 'A'..'Z', 0..9);
my @special_chars = split//, ',._!"#$%&/()=?\€<>;:\'';
my @country_codes = map { uc } all_country_codes();

my $opinion_picker  = fake_pick(qw< Luxe Sleek Elegant Stylish Refreshing Bold
Vibrant Chic Timeless Exquisite >);
my $size_picker     = fake_pick(qw< Tiny Small Medium Large Gigantic Petite Massive
Miniature Enormous Compact Long Tall Wide Narrow Slim Short >);
my $quality_picker  = fake_pick(qw< Handcrafted Organic Innovative Premium
Versatile Durable High-performance Sustainable >);
my $shape_picker    = fake_pick(qw< Round Square Oval Rectangular Triangular
Circular Diamond-shaped Heart-shaped Hexagonal Octagonal >);
my $age_picker      = fake_pick(qw< Vintage Old-Fashioned Classic Retro Modern New Brand-New >);
my $color_picker    = fake_pick(qw<Red Blue Green Yellow Orange Purple Pink Brown
Black White Gray Gold Silver Turquoise Maroon>);
my $material_picker = fake_pick(qw< Wood Metal Plastic Glass Fabric Leather
Ceramic Paper Stone Rubber Concrete Clay Vinyl Silk Wool Cotton Linen Bamboo
Polyester Foam >);
my $thing_picker    = fake_pick(qw< Accessories Accessory Art Automotive Baby
Beauty Book Boot Clothes Cosmetics Decor Decorations Electronic Equipment
Fitness Food Footwear Furniture Game Games Garden Gardening Gear Health Home
Jewelry Magazine Office Outdoor Party Pet Shoe Sport Stationery Supplies Tech
Tool Toy Travel Traveling>);
my $suffix_picker  = fake_pick(qw<Kit Set Pack Mix Collection>);

my %translations =  (   timestamp                   => sub { substr join("",split/\./, time), 0, 13 }
                    ,   alphanumeric                => sub { string_builder(15, @alphanums) }
                    ,   'name.firstName'            => sub { $faker->first_name() }
                    ,   'name.lastName'             => sub { $faker->last_name() }
                    ,   'name.prefix'               => sub { $faker->name_prefix() }
                    ,   'name.suffix'               => sub { $faker->name_suffix() }
                    ,   'name.title'                => sub { $faker->job_title() }
                    ,   'company.companyName'       => sub { $faker->company() }
                    ,   'address.streetAddress'     => sub { $faker->street_address() }
                    ,   'address.city'              => sub { $faker->city() }
                    ,   'address.state'             => sub { $faker->us_state() }
                    ,   'address.stateAbbr'         => sub { $faker->us_state_abbr() }
                    ,   'address.zipCode'           => sub { $faker->us_zip_code() }
                    ,   'address.countryCode'       => fake_pick(@country_codes)
                    ,   'phone.phoneNumber'         => sub { $faker->phone_number() }
                    ,   'phone.phoneNumberFormat'   => fake_digits('###-###-####')
                    ,   'image.avatar'              => sub { image_avatar() }
                    ,   'internet.email'            => fake_email()
                    ,   'internet.password'         => sub { string_builder(20, @alphanums, @special_chars) }
                    ,   'internet.ip'               => sub { $faker->ip_address() }
                    ,   'internet.color'            => sub { "#".join'', map { sprintf "%x", $_ }
                                                                         fake_array(3, fake_pick(0..255))->()->@*
                                                           }
                    ,   'date.month'                => fake_pick(@months)
                    ,   'date.weekday'              => fake_pick(@weekdays)
                    #,   'date.past'                 => sub { ... }
                    #,   'date.recent'               => sub { ... }
                    #,   'date.future'               => sub { ... }
                    #,   'date.soon'                 => sub { ... }
                    ,   'commerce.productName'      => \&product_name
                    ,   'commerce.price'            => sub { sprintf "%d.%02d", fake_int(1,9999)->(), fake_int(0,99)->() }
                    ,   'lorem.text'                => fake_paragraphs(1)
                    ,   'random.number'             => fake_int(1,99999)
                    ,   'random.uuid'               => sub { lc Data::GUID->new->as_string }
                    );

sub weave
{
    my ($value, %vars) = @_;
    $value //= '';
    $value =~ s/\{\{$_\}\}/$translations{$_}->()/ge for keys %translations;
    $value =~ s/\{\{$_\}\}/$vars{$_}/gx for keys %vars;
    $value;
}

sub string_builder
{
    my ($length, @chars) = @_;
    my $picker = fake_pick(@chars);
    sub
    {
        my $str;
        $str.= $picker->() while $length > length $str;
        return $str;
    }
}

# borrowed from [bchavez/Bogus](https://github.com/bchavez/Bogus)
sub image_avatar
{
    sprintf 'https://cloudflare-ipfs.com/ipfs/Qmd3W5DuhgHirLHGVixi6V76LhCkZUz6pnFt5AJBiyvHye/avatar/%d.jpg', fake_int(0, 1249)->();
}

sub product_name
{
    my @adj = (   rand > 0.75 ? $opinion_picker->()  : ()
              ,   rand > 0.75 ? $quality_picker->()  : ()
              ,   rand > 0.67 ? $size_picker->()     : ()
              ,   rand > 0.75 ? $shape_picker->()    : ()
              ,   rand > 0.75 ? $age_picker->()      : ()
              ,   rand > 0.67 ? $color_picker->()    : ()
              ,   rand > 0.75 ? $material_picker->() : ()
              );
    my $word = $thing_picker->();
    my $suffix = 0 == @adj || 'ing' eq substr($word, -3)
                 ? $suffix_picker->()
                 : "";
    join " ", @adj, $word, $suffix;
}
