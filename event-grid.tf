#--------------------------------------------------------Resource Group---------------------------------------------------------
locals {
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)

}
#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group ? 0 : 1 #Keep the bool value false to use data source else to use resource block use "true"
  name  = var.resource_group
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group)
  location = var.location
}

#------------------------------------------Event Grid Domain------------------------------------------------------
resource "azurerm_eventgrid_domain" "eventgrid" {
  name                          = var.eventgrid_name
  location                      = local.location
  resource_group_name           = local.resource_group_name
  input_schema                  = var.input_schema
  tags                          = var.tags
  public_network_access_enabled = var.public_network_access_enabled      

  inbound_ip_rule {
    ip_mask = var.ip_mask                                            
    action  = var.action                                           
  }

  #-------------------- Identity Block for Event Grid Domain is not supported through terraform---------------------#
  /*
  identity  {
    type = "SystemAssigned"
  }*/
}


#-----------------------------------RESOURCE: VIRTUAL NETWORK-------------------------------------------#
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  address_space       = var.address_space
  location            = local.location
  resource_group_name = local.resource_group_name
}

#-----------------------------------RESOURCE: SUBNET----------------------------------------------------#
resource "azurerm_subnet" "snet-ep" {
  count                                          = var.enable_private_endpoint ? 1 : 0
  name                                           = var.subnet_name
  resource_group_name                            = local.resource_group_name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = var.private_subnet_address_prefix
  enforce_private_link_endpoint_network_policies = var.enforce_private_link_endpoint_network_policies
}

#-----------------------------------RESOURCE: PRIVATE ENDPOINT------------------------------------------#
resource "azurerm_private_endpoint" "pep1" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = var.private_endpoint_name
  location            = local.location
  resource_group_name = local.resource_group_name
  subnet_id           = azurerm_subnet.snet-ep.0.id
  private_service_connection {
    name                           = var.private_service_connection_name
    is_manual_connection           = var.is_manual_connection
    private_connection_resource_id = azurerm_eventgrid_domain.eventgrid.id
    subresource_names              = var.subresource_names
  }
}

data "azurerm_private_endpoint_connection" "private-ip1" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = azurerm_private_endpoint.pep1.0.name
  resource_group_name = local.resource_group_name
  depends_on          = [azurerm_eventgrid_domain.eventgrid]
}

#--------------------------------------------------Storage Account-----------------------------------------------------------
resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = local.resource_group_name
  location                 = local.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
}