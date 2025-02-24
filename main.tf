# Create a client with the provided IAM token.
data "yandex_client_config" "client" {}

locals {
  # If not provided, infer folder ID from token access.
  folder_id               = var.folder_id == null ? data.yandex_client_config.client.folder_id : var.folder_id
  
  archive_filename        = try(data.external.archive_prepare[0].result.filename, null)
  archive_filename_string = local.archive_filename != null ? local.archive_filename : ""
  archive_was_missing     = try(data.external.archive_prepare[0].result.was_missing, false)

  # Use a generated filename to determine when the source code has changed.
  # filename - to get package from local
  filename    = var.local_existing_package != null ? var.local_existing_package : (var.store_on_bucket ? null : local.archive_filename)
  was_missing = var.local_existing_package != null ? !fileexists(var.local_existing_package) : local.archive_was_missing
  
  # If it's true that an existing resource should be used and its ID is provided, don't create a new resource.
  create_logging_group    = var.create_logging_group    && var.existing_log_group_id        != null ? true : false
  create_service_account  = var.create_service_account  && var.existing_service_account_id  != null ? true : false
}

resource "yandex_function" "this" {
  count = var.create ? 1 : 0

  name               = var.name
  description        = var.description
  
  entrypoint         = var.entrypoint
  runtime            = var.runtime
  memory             = var.memory
  tags               = var.tags
  environment        = var.environment
  execution_timeout  = min(var.execution_timeout, 3600)
  service_account_id = local.create_service_account ? var.existing_service_account_id : yandex_iam_service_account.default_cloud_function_sa[0].id
  user_hash          = var.ignore_source_code_hash ? null : (local.filename == null ? false : fileexists(local.filename)) && !local.was_missing ? filebase64sha256(local.filename) : null

  content {
    zip_filename = local.filename
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

resource "random_pet" "this" {
  length  = 2
}

# ##############################################################################
#                                 New Log Group                                 
# ##############################################################################

resource "yandex_logging_group" "default_log_group" {
  count       = var.create && local.create_logging_group ? 1 : 0

  description = "Cloud logging group for cloud function yc-function-example."
  folder_id   = local.folder_id
  name        = "yc-logging-group-${random_pet.this.id}"
}

# ##############################################################################
#                       New Service Account for Terraform                       
# ##############################################################################

resource "yandex_iam_service_account" "default_cloud_function_sa" {
  count       = var.create && local.create_service_account ? 0 : 1

  folder_id   = local.folder_id
  description = "IAM service account for cloud function yc-function-example."
  name        = try("${var.existing_service_account_name}-${random_pet.this.id}", "terraform-function-${random_pet.this.id}")
}

resource "yandex_resourcemanager_folder_iam_binding" "invoker" {
  depends_on  = [yandex_iam_service_account.default_cloud_function_sa]
  
  folder_id   = local.folder_id
  members     = ["serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}"]
  role        = "functions.functionInvoker"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  depends_on  = [yandex_iam_service_account.default_cloud_function_sa]

  folder_id   = local.folder_id
  members     = ["serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}"]
  role        = "editor"
}

resource "yandex_resourcemanager_folder_iam_binding" "lockbox_payload_viewer" {
  depends_on  = [yandex_iam_service_account.default_cloud_function_sa]
  
  folder_id   = local.folder_id
  members     = ["serviceAccount:${yandex_iam_service_account.default_cloud_function_sa[0].id}"]
  role        = "lockbox.payloadViewer"
}

resource "time_sleep" "wait_for_iam" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.invoker,
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.lockbox_payload_viewer
  ]

  create_duration = "5s"
}

# ##############################################################################
#                                    Lockbox                                    
# ##############################################################################

resource "yandex_lockbox_secret" "yc_secret" {
  count       = var.create ? 1 : 0

  description = "Lockbox secret for cloud function yc-function-example from tf-module terraform-yc-function."
  name        = "yc-lockbox-secret-${random_pet.this.id}"
}

resource "yandex_lockbox_secret_version" "yc_version" {
  depends_on  = [yandex_lockbox_secret.yc_secret]

  description = "Version of lockbox secret yc-lockbox-secret from tf-module terraform-yc-function."
  secret_id   = yandex_lockbox_secret.yc_secret[0].id
  entries {
    key        = var.lockbox_secret_key
    text_value = var.lockbox_secret_value
  }
}

# ##############################################################################
#                                   Function                                    
# ##############################################################################

resource "yandex_function_iam_binding" "function_iam" {
  depends_on  = [yandex_function.this]
  count       = var.publish ? 1 : 0

  function_id = [yandex_function.this.id]
  members     = ["system:allUsers"]
  role        = "functions.functionInvoker"
}

resource "yandex_function_trigger" "yc_trigger" {
  count       = var.create && var.create_trigger ? 1 : 0

  name        = "yc-function-trigger-${random_pet.this.id}"
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
  depends_on  = [yandex_function.this]
  
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
