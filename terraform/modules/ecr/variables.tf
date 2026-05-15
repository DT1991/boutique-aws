variable "prefix" {
  type    = string
  default = "online-boutique"
}

variable "service_names" {
  type = list(string)
  default = [
    "frontend",
    "cartservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "shippingservice",
    "emailservice",
    "checkoutservice",
    "recommendationservice",
    "adservice",
    "loadgenerator",
  ]
}

variable "tags" {
  type    = map(string)
  default = {}
}
