package BalancedPayments;
use Moo;
with 'BalancedPayments::HTTP';

use Carp qw(croak);

has secret      => (is => 'ro', required => 1                             );
has merchant    => (is => 'rw', lazy => 1, builder => '_build_merchant'   );
has marketplace => (is => 'rw', lazy => 1, builder => '_build_marketplace');

has api_keys_uri     => (is => 'ro', default => sub { '/v1/api_keys'     });
has merchants_uri    => (is => 'ro', default => sub { '/v1/merchants'    });
has marketplaces_uri => (is => 'ro', default => sub { '/v1/marketplaces' });
has cards_uri => (
    is      => 'ro',
    lazy    => 1,
    default => sub { shift->marketplace->{cards_uri} }
);
has accounts_uri => (
    is      => 'ro',
    lazy    => 1,
    default => sub { shift->marketplace->{accounts_uri} }
);

sub _build_merchant {
    my ($self) = @_;
    my $data = $self->get($self->merchants_uri);
    return $data->{items}[0];
}

sub _build_marketplace {
    my ($self) = @_;
    my $data = $self->get($self->marketplaces_uri);
    return $data->{items}[0];
}

sub get_card {
    my ($self, $id) = @_;
    return $self->get($self->cards_uri . "/$id");
}

sub create_card {
    my ($self, $card) = @_;
    croak 'The card param must be a hashref' unless ref $card eq 'HASH';
    return $self->post($self->cards_uri, $card);
}

sub get_account {
    my ($self, $id) = @_;
    return $self->get($self->accounts_uri . "/$id");
}

sub create_account {
    my ($self, $account, $card) = @_;
    croak 'The account param must be a hashref' unless ref $account eq 'HASH';
    croak 'The account requires an email_address field'
        unless $account->{email_address};
    if ($card) {
        croak 'The card param must be a hashref' unless ref $card eq 'HASH';
        croak 'The card is missing a uri' unless $card->{uri};
        $account->{card_uri} = $card->{uri};
    }
    return $self->post($self->accounts_uri, $account);
}

sub add_card {
    my ($self, $card, $account) = @_;
    croak 'The card param must be a hashref' unless ref $card eq 'HASH';
    croak 'The account param must be a hashref' unless ref $account eq 'HASH';
    croak 'The account requires a cards_uri field' unless $account->{cards_uri};
    return $self->post($account->{cards_uri}, $card);
}

sub create_hold {
    my ($self, $hold, $data) = @_;
    croak 'The hold param must be a hashref' unless ref $hold eq 'HASH';
    croak 'The hold is missing an amount field' unless $hold->{amount};
    croak 'The account or card param must be a hashref'
        unless ref $data eq 'HASH';
    my $holds_uri = $data->{holds_uri} || $data->{account}{holds_uri}
        or die 'No holds_uri found';
    if ($data->{card_type} and $data->{uri}) { # If a card is provided
        $hold->{card_uri} = $data->{uri}
    }
    return $self->post($holds_uri, $hold);
}

sub create_debit {
    my ($self, $debit, $account) = @_;
    croak 'The debit param must be a hashref' unless ref $debit eq 'HASH';
    croak 'The debit is missing an amount field' unless $debit->{amount};
    croak 'The account param must be a hashref' unless ref $account eq 'HASH';
    croak 'The account requires a debits_uri field'
        unless $account->{debits_uri};
    return $self->post($account->{debits_uri}, $debit);
}

# ABSTRACT: BalancedPayments API bindings

=head1 SYNOPSIS

    use BalancedPayments;

    my $secret = 'abc123';
    my $bp = BalancedPayments->new(secret => $secret);

    my $card = $bp->create_card({
        card_number      => "5105105105105100",
        expiration_month => 12,
        expiration_year  => 2020,
        security_code    => 123,
    });

    $bp->get_card($card->{id});

=head1 DESCRIPTION

This module provides bindings for the
L<BalancedPayments|https://www.balancedpayments.com> API.

=head1 METHODS

=head2 get_card

    get_card($id)

Returns a credit card for the given id.

Example response:

    { 
        account          => { ... },
        brand            => "MasterCard",
        card_type        => "mastercard",
        created_at       => "2012-06-07T11:00:40.003671Z",
        expiration_month => 12,
        expiration_year  => 2020,
        id               => "CC92QRQcwUCp5zpzEz7lXKS",
        is_valid         => 1,
        last_four        => 5100,
        name             => undef,
        uri              => "/v1/marketplaces/MK98f1/cards/CC92QRQcwUCp5zpzKS",
    }

=head2 create_card

    create_card({
        card_number      => "5105105105105100",
        expiration_month => 12,
        expiration_year  => 2020,
        security_code    => 123,
    })

Creates a credit card and returns the server's representation of it.
See L</get_card> for an example response.

=head2 get_account

    get_account($id)

Returns an account for the given id.

Example response:

 {
     id                => "AC7A",
     uri               => "/v1/marketplaces/MK98/accounts/AC7A",
     email_address     => "naveed\@crowdtilt.com",
     meta              => {},
     name              => undef,
     roles             => [],
     created_at        => "2012-06-07T21:01:38.801460Z",
     bank_accounts_uri => "/v1/marketplaces/MK98/accounts/AC7A/bank_accounts",
     cards_uri         => "/v1/marketplaces/MK98/accounts/AC7A/cards",
     credits_uri       => "/v1/marketplaces/MK98/accounts/AC7A/credits",
     debits_uri        => "/v1/marketplaces/MK98/accounts/AC7A/debits",
     holds_uri         => "/v1/marketplaces/MK98/accounts/AC7A/holds",
     refunds_uri       => "/v1/marketplaces/MK98/accounts/AC7A/refunds",
     transactions_uri  => "/v1/marketplaces/MK98/accounts/AC7A/transactions",
 }

=head2 create_account

    create_account({ email_address => 'bob@crowdtilt.com' })
    create_account({ email_address => 'bob@crowdtilt.com' }, $card)
    create_account({
        email_address => 'bob@crowdtilt.com',
        card_uri => "/v1/marketplaces/MK98/cards/CC92QRQcwUCp5zpzEz7lXKS",
    })

Creates an account.
An account hashref is required and an optional card hashref may be provided as
well.
The account hashref must provide an email_address field.
It is possible to create an account and associate it with a credit card at the
same time.
You can do this in 2 ways.
You can provide a card such as one returned by calling L</get_card>:

    my $card = $bp->get_card($card_id);
    create_account({ email_address => 'bob@crowdtilt.com' }, $card);

Alternatively, you can provide a card_uri inside the C<$account> hashref:

    $bp->create_account({
        email_address => 'bob@crowdtilt.com',
        card_uri      => $card->{uri},
    })

Returns an account hashref.
See L</get_account> for an example response.

=head2 add_card

    add_card($card, $account)

Adds a card to an account.
It expects a card hashref, such as one returned by L</get_card>,
and an account hashref, such as one returned by L</get_account>.

Returns an account hashref.
See L</get_account> for an example response.

=head2 create_hold

    create_hold ({ amount => 200 }, $account)
    create_hold ({ amount => 200 }, $card)

Creates a hold for the given account.
It expects a hold hashref which at least contains an amount field.
The amount must be an integer value >= 200.

An account or card must be provided.
If an account is provided, Balanced defaults to charging the most recently
added card for the account.

You can pass in a card if you want to charge a specific card:

    my $card = bp->get_card($card_id);
    create_hold ({ amount => 200 }, $card)

B<NOTE:> Passing in a card currently does not work.
The api still charges the most recently added card for some reason.

Returns a hold hashref.
Example response:

 {
   id          => "HL5byxIzSvf0entZuO9eEsWJ",
   uri         => "/v1/marketplaces/MK98/holds/HL5byxIzSvf0entZuO9eEsWJ",
   amount      => 200,
   account     => { ... },
   created_at  => "2012-06-08T09:23:53.745746Z",
   debit       => undef,
   description => undef,
   expires_at  => "2012-06-15T09:23:53.705009Z",
   fee         => 35,
   is_void     => 0,
   meta        => {},
   source => {
     brand            => "MasterCard",
     card_type        => "mastercard",
     created_at       => "2012-06-07T11:00:40.003671Z",
     expiration_month => 12,
     expiration_year  => 2020,
     id               => "CC92QRQcwUCp5zpzEz7lXKS",
     is_valid         => 1,
     last_four        => 5100,
     name             => undef,
     uri => "/v1/marketplaces/MK98/accounts/AC7A/cards/CC92QRQcwUCp5zpzEz7lXKS",
   },
 }

=head2 create_debit

    create_debit ({ amount => 200 }, $account)

Creates a debit for the given account.
It expects a debit hashref which at least contains an amount field.
An account hashref, such as one returned by L</get_account>, is also required.

Returns a debit hashref.
Example response.

 {
   id                       =>  "WD2Lpzyz8Okbhx2Nbw7YuTP3",
   uri                      =>  "/v1/marketplaces/MK98/debits/WD2L",
   account                  =>  { ... },
   amount                   =>  50,
   appears_on_statement_as  =>  "example.com",
   available_at             =>  "2012-06-08T09:57:27.686977Z",
   created_at               =>  "2012-06-08T09:57:27.750828Z",
   description              =>  undef,
   fee                      =>  1,
   hold                     =>  { ... },
   meta                     =>  {},
   refunds_uri              =>  "/v1/marketplaces/MK98/debits/WD2L/refunds",
   source => {
     brand            => "MasterCard",
     card_type        => "mastercard",
     created_at       => "2012-06-07T11:00:40.003671Z",
     expiration_month => 12,
     expiration_year  => 2020,
     id               => "CC92QRQcwUCp5zpzEz7lXKS",
     is_valid         => 1,
     last_four        => 5100,
     name             => undef,
     uri => "/v1/marketplaces/MK98/accounts/AC7A/cards/CC92QRQcwUCp5zpzEz7lXKS",
   },
   transaction_number => "W476-365-3767",
 }

=cut

1;
