variable "gce_ssh_pub_key_file" {
  type=string
  description = "The location of the ssh pub key."

  default=""
}

variable "gce_ssh_user" {
  type=string
  description = "The username of the ssh pub key."

  default=""
}

terraform {
  backend "gcs" {
    prefix = "terraria/state"
    bucket = "terraform-terraria-imprompt"
  }
}

locals {
  project = "imprompt-server"
  region = "asia-southeast1"
  zone = "asia-southeast1-b"
  credentials = file("../account.json")
}

provider "google" {
  credentials = local.credentials
  project = local.project
  region = local.region
}

resource "google_service_account" "terraria" {
  account_id = "terraria"
  display_name = "terraria"
}

resource "google_compute_disk" "terraria" {
  name = "terraria"
  type = "pd-standard"
  zone = local.zone
  image = "cos-cloud/cos-stable"
}

resource "google_compute_address" "terraria" {
  name = "terraria-ip"
  region = local.region
}

resource "google_compute_instance" "terraria" {
  name = "terraria"
  machine_type = "n1-custom-4-4096"
  allow_stopping_for_update = true

  zone = local.zone
  tags = [
    "terraria"]

  boot_disk {
    auto_delete = false
    # Keep disk after shutdown (game data)
    source = google_compute_disk.terraria.self_link
  }

  network_interface {
    network = google_compute_network.terraria.name
    access_config {
      nat_ip = google_compute_address.terraria.address
    }
  }

  service_account {
    email = google_service_account.terraria.email
    scopes = [
      "userinfo-email"]
  }

  scheduling {
    preemptible = true
    # Closes within 24 hours (sometimes sooner)
    automatic_restart = false
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
    # Run ryanechia/terraria-vanilla-server docker image on startup
    startup_script = "docker run -d -p 7777:7777 -v /var/terraria:/data --name terraria --rm=true ryanechia/terraria-vanilla-server:1404-1;"
  }

}

resource "google_compute_network" "terraria" {
  name = "terraria"
}

resource "google_compute_firewall" "terraria" {
  name = "terraria"
  network = google_compute_network.terraria.name
  # Terraria client port
  allow {
    protocol = "tcp"
    ports = [
      "7777"]
  }
  # ICMP (ping)
  allow {
    protocol = "icmp"
  }
  # SSH
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [
    "0.0.0.0/0"]
  target_tags = [
    "terraria"]
}
