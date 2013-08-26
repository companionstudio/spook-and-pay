# Spook and Pay

A small library which wraps payment and credit card vaulting providers that support transparent redirect.

The aim is to make switching between providers easy or even support multiple providers within the same application.

Initially this library will support Braintree and SpreedlyCore, with more added as needed.

## Alpha Warning

This library is currently in-flight; you're welcome to hack on it, but it's unlikely to be usable.

## Usage

All actions are run via an instance of a `SpookAndPay::Providers::Base` subclass. Configuration is dependent on the particular provider you are using. For example, here is how you would configure Braintree:

```
provider = SpookAndPay::Providers::Braintree.new(
  :development,
  :merchant_id => "...",
  :public_key => "...",
  :secret_key => "...",
)
```

You can then use the provider instance to interrogate Braintree and to perform actions.

```
transaction = provider.transaction('...')
transaction.status # => :settling
transaction.can_refund? # => false
transaction.can_void? # => true

result = transaction.void!
result.successful? # => true
```

### Workflow

Currently SpookAndPay does not support the direct submission of payment details — credit card numbers etc — but instead relies on payment providers which feature transparent redirect/post for submission of details.

Direct submission of details will _never_ be supported, since it raises the specter of PCI-compliance.

### Transparent Redirect

TBD

## Todo

* Normalise transaction statuses across providers
* Normalise errors across providers
* Implement actions on CreditCard e.g. update, delete
