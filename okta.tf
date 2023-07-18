data "okta_user" "me" {
  user_id = "me"
}

resource "okta_group" "admin" {
  name        = "tmc:admin"
  description = "TMC Admin Group"
}
resource "okta_group" "member" {
  name        = "tmc:member"
  description = "TMC Member Group"
}

resource "okta_group_memberships" "self" {
  group_id = okta_group.admin.id
  users    = [data.okta_user.me.id]
}

resource "okta_app_oauth" "tmc" {
  type  = "web"
  label = "TMC Self Managed"
  grant_types = [
    "authorization_code",
    "refresh_token",
    "password"
  ]
  redirect_uris = [
    "https://pinniped-supervisor.${local.dns_tmc_domain}/provider/pinniped/callback"
  ]
}
