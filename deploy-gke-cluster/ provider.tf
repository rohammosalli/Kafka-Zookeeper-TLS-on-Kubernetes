provider "google" {
  credentials = "${file("./creds/serviceaccount.json")}"
  project     = "amir-250512"
  region      = "us-central1"
  zone        = "us-central1-a"

}