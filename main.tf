data "yandex_client_config" "client" {}

locals {
  # If not provided, infer folder ID from token access.
  folder_id = var.folder_id == null ? data.yandex_client_config.client.folder_id : var.folder_id

  # If it's true that an existing resource should be used and its ID is provided, don't create a new resource.
  create_logging_group   = var.create_logging_group && var.existing_log_group_id != null ? true : false
  create_service_account = var.create_service_account && var.existing_service_account_id != null ? true : false

  zip_filename = var.zip_filename == null ? archive_file.function[0].output_path : var.zip_filename
  user_hash    = archive_file.function[0].output_sha256
}

resource "yandex_function" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags

  runtime     = var.runtime
  entrypoint  = var.entrypoint
  environment = var.environment

  memory            = var.memory
  execution_timeout = var.execution_timeout

  user_hash          = local.user_hash
  service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id

  content {
    zip_filename = local.zip_filename
  }

  log_options {
    log_group_id = coalesce(var.existing_log_group_id, try(yandex_logging_group.default_log_group[0].id, ""))
    min_level    = var.min_level
  }

  dynamic "storage_mounts" {
    for_each = var.mount_bucket != true ? [] : tolist(1)
    content {
      mount_point_name = var.storage_mounts.mount_point_name
      bucket           = var.storage_mounts.bucket
      prefix           = var.storage_mounts.prefix
      read_only        = var.storage_mounts.read_only
    }
  }
  connectivity {
    network_id = var.network_id != null ? var.network_id : ""
  }

  secrets {
    id                   = yandex_lockbox_secret.yc_secret.id
    version_id           = yandex_lockbox_secret_version.yc_version.id
    key                  = var.lockbox_secret_key
    environment_variable = var.environment_variable
  }

  dynamic "async_invocation" {
    for_each = var.use_async_invocation != true ? [] : tolist(1)
    content {
      retries_count      = var.retries_count
      service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
      ymq_failure_target {
        service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
        arn                = var.ymq_failure_target
      }
      ymq_success_target {
        service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
        arn                = var.ymq_success_target
      }
    }
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.invoker,
    yandex_resourcemanager_folder_iam_binding.lockbox_payload_viewer,
    time_sleep.wait_for_iam
  ]
}

resource "archive_file" "function" {
  count = var.zip_filename == null ? 1 : 0

  type = "zip"

  source_file = var.source_path
  output_path = "${path.module}/.terraform/tmp"
}

resource "yandex_function_iam_binding" "function_iam" {
  count = var.public_access ? 1 : 0

  function_id = yandex_function.this.id
  role        = "functions.functionInvoker"
  members = [
    "system:allUsers",
  ]
}

resource "yandex_function_trigger" "yc_trigger" {
  count = var.create_trigger ? 1 : 0

  name        = var.name
  description = "Specific cloud function trigger type yc-function-trigger for cloud function yc-function-example."

  dynamic "logging" {
    for_each = var.choosing_trigger_type == "logging" ? [yandex_function.this.id] : []
    content {
      group_id       = var.logging.group_id
      resource_types = var.logging.resource_types
      levels         = var.logging.levels
      batch_cutoff   = var.logging.batch_cutoff
      batch_size     = var.logging.batch_size
    }
  }

  dynamic "timer" {
    for_each = var.choosing_trigger_type == "timer" ? [yandex_function.this.id] : []
    content {
      cron_expression = var.timer.cron_expression
    }
  }

  dynamic "object_storage" {
    for_each = var.choosing_trigger_type == "object_storage" ? [yandex_function.this.id] : []
    content {
      bucket_id    = var.object_storage.bucket_id
      create       = var.object_storage.create
      update       = var.object_storage.update
      delete       = var.object_storage.delete
      batch_cutoff = var.object_storage.batch_cutoff
      batch_size   = var.object_storage.batch_size
    }
  }

  dynamic "message_queue" {
    for_each = var.choosing_trigger_type == "message_queue" ? [yandex_function.this.id] : []
    content {
      queue_id           = var.message_queue.queue_id
      service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
      batch_cutoff       = var.message_queue.batch_cutoff
      batch_size         = var.message_queue.batch_size
      visibility_timeout = var.message_queue.visibility_timeout
    }
  }

  function {
    id                 = yandex_function.this.id
    service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.invoker,
    yandex_resourcemanager_folder_iam_binding.lockbox_payload_viewer,
    time_sleep.wait_for_iam
  ]
}

resource "yandex_function_scaling_policy" "yc_scaling_policy" {
  function_id = yandex_function.this.id

  dynamic "policy" {
    for_each = var.scaling_policy
    content {
      tag                  = policy.value.tag
      zone_instances_limit = policy.value.zone_instances_limit
      zone_requests_limit  = policy.value.zone_requests_limit
    }
  }
}

# ##############################################################################
#                                 New Log Group                                 
# ##############################################################################

resource "yandex_logging_group" "default_log_group" {
  count = local.create_logging_group ? 0 : 1

  description = "Cloud logging group for cloud function yc-function-example."
  folder_id   = local.folder_id
  name        = var.name
}

# ##############################################################################
#                       New Service Account for Terraform                       
# ##############################################################################

resource "yandex_iam_service_account" "default_cloud_function_sa" {
  count = local.create_service_account ? 0 : 1

  description = "IAM service account for cloud function yc-function-example."
  folder_id   = local.folder_id
  name        = var.name
}

resource "yandex_resourcemanager_folder_iam_binding" "invoker" {
  depends_on = [yandex_iam_service_account.default_cloud_function_sa]

  folder_id = local.folder_id
  role      = "functions.functionInvoker"
  members = [
    "serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  depends_on = [yandex_iam_service_account.default_cloud_function_sa]

  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "lockbox_payload_viewer" {
  depends_on = [yandex_iam_service_account.default_cloud_function_sa]

  folder_id = local.folder_id
  role      = "lockbox.payloadViewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}",
  ]
}

resource "time_sleep" "wait_for_iam" {
  create_duration = "5s"
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.invoker,
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.lockbox_payload_viewer
  ]
}

# ##############################################################################
#                                    Lockbox                                    
# ##############################################################################

resource "yandex_lockbox_secret" "yc_secret" {
  description = "Lockbox secret for cloud function yc-function-example from tf-module terraform-yc-function."
  name        = coalesce(var.name)
}

resource "yandex_lockbox_secret_version" "yc_version" {
  description = "Version of lockbox secret yc-lockbox-secret from tf-module terraform-yc-function."
  secret_id   = yandex_lockbox_secret.yc_secret.id
  entries {
    key        = var.lockbox_secret_key
    text_value = var.lockbox_secret_value
  }
}