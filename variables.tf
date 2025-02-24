# For the sake of conditional creation.
variable "create" {
  description = "Controls if resources should be created"
  type        = bool
  default     = true
}

variable "create_logging_group" {
  description = "Controls if logging group should be created."
  type        = bool
  default     = false

  validation {
    condition = var.create_logging_group == false || var.existing_log_group_id != null
    error_message = "When `create_logging_group` is `true`, `existing_log_group_id` must be set."
  }
}

variable "create_service_account" {
  description = "Controls if service accounts should be created."
  type        = bool
  default     = false
  
  validation {
    condition = var.create_service_account == false || var.existing_service_account_id != null
    error_message = "When `create_service_account` is `true`, `existing_service_account_id` must be set."
  }
}

variable "create_trigger" {
  description = "Controls if Function trigger should be created."
  type        = bool
  default     = false

  validation {
    condition     = var.create_trigger == false || var.choosing_trigger_type != null
    error_message = "When `create_trigger` is `true`, `choosing_trigger_type` must be set."
  }
}

variable "create_package" {
  description = "Controls if package should be created."
  type        = bool
  default     = true
}

variable "name" {
  description = "A unique name for your Cloud Function"
  type        = string
  default     = "yc-custom-function-name"
}

variable "description" {
  description = "Description of your Cloud Function"
  type        = string
  default     = "yc-custom-function-description"
}

variable "local_existing_package" {
  description = "The absolute path to an existing zip-file to use"
  type        = string
  default     = null
}

variable "store_on_bucket" {
  description = "Whether to store produced artifacts on a bucket or locally."
  type        = bool
  default     = false
}

variable "ignore_source_code_hash" {
  description = "Whether to ignore changes to the function's source code hash. Set to true if you manage infrastructure and code deployments separately."
  type        = bool
  default     = false
}

variable "use_async_invocation" {
  description = "Whether to use asynchronous invocation to message queue or not."
  type        = bool
  default     = false

  validation {
    condition     = var.use_async_invocation == false || (var.ymq_success_target != null && var.ymq_failure_target != null)
    error_message = "When `use_async_invocation` is `true`, `ymq_success_target` and `ymq_failure_target` must be set."
  }
}

variable "publish" {
  description = "Whether to publish function's url or not."
  type        = bool
  default     = false
}

variable "build_in_docker" {
  description = "Whether to build dependencies in Docker"
  type        = bool
  default     = false
}

variable "docker_file" {
  description = "Path to a Dockerfile when building in Docker"
  type        = string
  default     = ""
}

variable "docker_build_root" {
  description = "Root dir where to build in Docker"
  type        = string
  default     = ""
}

variable "docker_image" {
  description = "Docker image to use for the build"
  type        = string
  default     = ""
}

variable "docker_with_ssh_agent" {
  description = "Whether to pass SSH_AUTH_SOCK into docker environment or not"
  type        = bool
  default     = false
}

variable "docker_pip_cache" {
  description = "Whether to mount a shared pip cache folder into docker environment or not"
  type        = any
  default     = null
}

variable "docker_additional_options" {
  description = "Additional options to pass to the docker run command (e.g. to set environment variables, volumes, etc.)"
  type        = list(string)
  default     = []
}

variable "docker_entrypoint" {
  description = "Path to the Docker entrypoint to use"
  type        = string
  default     = null
}

variable "tags" {
  description = "List of tags for cloud function yc-function-example."
  type        = list(string)
  default     = ["yc_tag"]
}

variable "user_hash" {
  description = <<EOF
    User-defined string for current function version.
    User must change this string any times when function changed. 
    Function will be updated when hash is changed."
  EOF
  default     = "yc-defined-string-for-tf-module"
  type        = string
}

variable "scaling_policy" {
  description = "List of scaling policies for cloud function yc-function-example."
  type = list(object({
    tag                  = string
    zone_instances_limit = number
    zone_requests_limit  = number
  }))
}

variable "existing_service_account_name" {
  description = "Existing IAM service account name."
  type        = string
  default     = null
}

variable "existing_service_account_id" {
  description = "Existing IAM service account id."
  type        = string
  default     = null # "ajebc0l7qlklv3em6ln9"
}

variable "folder_id" {
  description = "The ID of the folder that the cloud function yc-function-example belongs to."
  type        = string
  default     = null
}
variable "runtime" {
  description = "Runtime for cloud function yc-function-example."
  type        = string
  default     = "bash-2204"
}

variable "entrypoint" {
  description = "Entrypoint for cloud function yc-function-example."
  type        = string
  default     = "handler.sh"
}

variable "memory" {
  description = "Memory in megabytes for cloud function yc-function-example."
  type        = number
  default     = 128

  validation {
    condition = (
      var.memory >= 128 &&
      var.memory <= 4096
    )
    error_message = "Must be between 128 and 4096 seconds, inclusive."
  }
}

variable "execution_timeout" {
  description = "Execution timeout in seconds for cloud function yc-function-example."
  type        = number
  default     = 10
}

variable "zip_filename" {
  description = "Filename to zip archive for the version of cloud function's code."
  type        = string
  default     = "../../handler.zip"
}

variable "choosing_trigger_type" {
  description = "Choosing type for cloud function trigger."
  type        = string
  validation {
    condition     = contains(["logging", "timer", "object_storage", "message_queue", ""], var.choosing_trigger_type)
    error_message = "Trigger type should be logging, timer, object_storage, message_queue or empty string."
  }
}

variable "network_id" {
  description = "Cloud function's network id for VPC integration."
  type        = string
  default     = null # "enp9rm1debn7usfmtlnv"
}

variable "logging" {
  description = "Trigger type of logging."
  type = object({
    group_id       = string
    resource_ids   = optional(list(string))
    resource_types = optional(list(string), ["serverless.function"])
    levels         = optional(list(string), ["INFO"])
    batch_cutoff   = number
    batch_size     = number
    stream_names   = optional(list(string))
  })
  default = {
    group_id     = null
    batch_cutoff = 1
    batch_size   = 1
  }
}

variable "timer" {
  description = "Trigger type of timer."
  type = object({
    cron_expression = optional(string, "*/30 * ? * * *")
    payload         = optional(string)
  })
  default = {
    cron_expression = "*/5 * ? * * *"
    payload         = null
  }
}

variable "object_storage" {
  description = "Trigger type of object storage."
  type = object({
    bucket_id    = string
    prefix       = optional(string)
    suffix       = optional(string)
    create       = optional(bool, true)
    update       = optional(bool, true)
    delete       = optional(bool, true)
    batch_cutoff = number
    batch_size   = number
  })
  default = {
    bucket_id    = null
    batch_cutoff = 1
    batch_size   = 1
  }
}

variable "message_queue" {
  description = "Trigger type of message queue."
  type = object({
    queue_id           = string
    service_account_id = optional(string)
    batch_cutoff       = number
    batch_size         = number
    visibility_timeout = optional(number, 600)
  })
  default = {
    queue_id           = null
    service_account_id = null
    batch_cutoff       = 1
    batch_size         = 1
  }
}



variable "existing_log_group_id" {
  description = "Existing logging group id."
  type        = string
  default     = null # "e23moaejmq8m74tssfu9"
}

variable "min_level" {
  description = "Minimal level of logging for cloud function yc-function-example."
  type        = string
  default     = "ERROR"
}

variable "lockbox_secret_key" {
  description = "Lockbox secret key for cloud function yc-function-example."
  type        = string
}

variable "lockbox_secret_value" {
  description = "Lockbox secret value for cloud function yc-function-example."
  type        = string
}

variable "environment_variable" {
  description = "Function's environment variable in which secret's value will be stored."
  type        = string
  default     = "ENV_VARIABLE"
}



variable "mount_bucket" {
  description = "Mount bucket (true) or not (false). If `true` section `storage_mounts{}` should be defined."
  type        = bool
  default     = false
}

variable "storage_mounts" {
  description = "Mounting s3 bucket."
  type = object({
    mount_point_name = string
    bucket           = string
    prefix           = optional(string)
    read_only        = optional(bool, true)
  })
  default = {
    mount_point_name = "yc-function"
    bucket           = null
  }
}

variable "retries_count" {
  description = "Maximum number of retries for async invocation."
  type        = number
  default     = 3
}

variable "ymq_success_target" {
  description = "Target for successful async invocation."
  type        = string
  default     = null # "yrn:yc:ymq:ru-central1:b1gdddu3a9appamt3aaa:ymq-success"
}

variable "ymq_failure_target" {
  description = "Target for unsuccessful async invocation."
  type        = string
  default     = null # "yrn:yc:ymq:ru-central1:b1gdddu3a9appamt3aaa:ymq-failure"
}

variable "environment" {
  description = "A set of key/value environment variables for Yandex Cloud Function from tf-module"
  type        = map(string)
  default = {
    "name"    = "John"
    "surname" = "Wick"
  }
}