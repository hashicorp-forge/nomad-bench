resource "ansible_group" "server" {
  name = "${replace(var.project_name, "-", "_")}_server"
}

resource "ansible_host" "server" {
  for_each = { for s in aws_instance.servers : s.tags.Name => s.private_ip }

  name   = each.key
  groups = [ansible_group.server.name]
  variables = {
    ansible_host = each.value
  }
}

resource "ansible_group" "client" {
  name = "${replace(var.project_name, "-", "_")}_client"
}

resource "ansible_host" "client" {
  for_each = { for s in aws_instance.clients : s.tags.Name => s.private_ip }

  name   = each.key
  groups = [ansible_group.client.name]
  variables = {
    ansible_host = each.value
  }
}
