locals {
  graph_id_base = 100
  number_of_graphs_per_bucket = 2
}

data "template_file" "grafana_graphs" {
  count = length(local.schemas_info)
  template = file("${path.module}/templates/grafana-graph.tpl")
  vars = {
    bucket_name = local.schemas_info[count.index]["data_bucket"]
    title_bucket_name = local.schemas_info[count.index]["resource_suffix"]
    graph_id = range(local.graph_id_base, local.graph_id_base + length(local.schemas_info) * local.number_of_graphs_per_bucket, local.number_of_graphs_per_bucket)[count.index]
    aws_region = data.aws_region.current.name
  }
}

data "template_file" "grafana_dashboard_data" {
  template = file("${path.module}/templates/grafana-dashboard.tpl")
  vars = {
    panels = "[${join(",", data.template_file.grafana_graphs.*.rendered)}]"
  }
}

resource "kubernetes_config_map" "grafana_dashboard" {
  count = var.hms_instance_type == "k8s" ? 1 : 0
  metadata {
    name = "apiary-data-lake-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard="true"
    }
  }

  data = {
    "apiary-data-lake-dashboard.json" = data.template_file.grafana_dashboard_data.rendered
  }
}