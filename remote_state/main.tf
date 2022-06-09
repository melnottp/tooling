resource "flexibleengine_obs_bucket" "admin_bucket" {
  bucket     = "admin-state"
  acl        = "private"
  versioning = true
}

resource "flexibleengine_obs_bucket" "tools_bucket" {
  bucket     = "tools-state"
  acl        = "private"
  versioning = true
}

