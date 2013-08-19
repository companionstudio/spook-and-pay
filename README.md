# Spook and Pay

A small library which wraps payment and credit card vaulting providers that support transparent redirect.

The aim is to make switching between providers easy or even support multiple providers within the same application.

Initially this library will support Braintree and SpreedlyCore, with more added as needed.

## Alpha Warning

This library is currently in-flight; you're welcome to hack on it, but it's unlikely to be usable.

## Todo

* Normalise transaction statuses across providers
* Normalise errors across providers
* Implement actions on CreditCard e.g. update, delete
* Create helpers for generating forms
* Create Payment object for use in forms; it wraps values and errors compatible with ActionView 
