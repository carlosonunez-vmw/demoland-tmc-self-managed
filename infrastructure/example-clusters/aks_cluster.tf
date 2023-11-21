resource "azurerm_resource_group" "things" {
  name     = "tmc-cluster-example"
  location = "Central US"
}

resource "azurerm_kubernetes_cluster" "tmc-example" {
  resource_group_name = azurerm_resource_group.things.name
  location            = azurerm_resource_group.things.location
  name                = "tmc-example"
  dns_prefix          = "tmcexample"
  default_node_pool {
    name                = "default"
    vm_size             = "Standard_D2_v5"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
  }
  identity {
    type = "SystemAssigned"
  }
}
