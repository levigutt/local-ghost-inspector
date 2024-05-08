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
                    #,   'image.avatar'              => sub { ... }
                    ,   'internet.email'            => fake_email()
                    ,   'internet.password'         => sub { string_builder(20, @alphanums, @special_chars) }
                    ,   'internet.ip'               => sub { $faker->ip_address() }
                    ,   'internet.color'            => sub { "#".join'', map { sprintf "%x", $_ }
                                                                         fake_array(3, fake_pick(0..255))->()->@*
                                                           }
                    ,   'date.month'                => fake_pick(@months)
                    ,   'date.weekday'              => fake_pick(@weekdays)
                    #,   'data.past'                 => sub { ... }
                    #,   'data.future'               => sub { ... }
                    #,   'commerce.productName'      => sub { ... }
                    ,   'commerce.price'            => sub { sprintf "%d.%02d", fake_int(1,9999)->(), fake_int(0,99)->() }
                    ,   'lorem.text'                => fake_paragraphs(1)
                    ,   'random.number'             => fake_int(1,99999)
                    ,   'random.uuid'               => sub { lc Data::GUID->new->as_string }
                    );

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


sub weave
{
    my ($value, %vars) = @_;
    $value //= '';
    $value =~ s/\{\{$_\}\}/$translations{$_}->()/ge for keys %translations;
    $value =~ s/\{\{$_\}\}/$vars{$_}/gx for keys %vars;
    $value;
}

