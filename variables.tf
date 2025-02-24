# Variable "create" or "enable" is not used
# because this module lives after the release of 0.13
# where `count` was introduced for entire modules.

variable "create_logging_group" {
  description = "Controls if logging group should be created."
  type        = bool
  default     = false
}

variable "create_service_account" {
  description = "Controls if service account should be created."
  type        = bool
  default     = false
}

variable "create_trigger" {
  description = "Controls if trigger should be created."
  type        = bool
  default     = false
}

# ##############################################################################
# Function                                                                      
# ##############################################################################

variable "name" {
  description = "Custom Cloud Function name from tf-module"
  type        = string
  default     = null
}

variable "description" {
  description = "Custom Cloud Function description from tf-module"
  type        = string
  default     = null
}

variable "tags" {
  description = "List of tags for cloud function yc-function-example."
  type        = list(string)
  default     = null
}

variable "folder_id" {
  description = "The ID of the folder that the cloud function yc-function-example belongs to."
  type        = string
  default     = null
}

variable "runtime" {
  description = "Runtime for cloud function yc-function-example."
  type        = string
  default     = null
}

variable "entrypoint" {
  description = "Entrypoint for cloud function yc-function-example."
  type        = string
  default     = null
}

variable "environment" {
  description = "A set of key/value environment variables for Yandex Cloud Function from tf-module"
  type        = map(string)
  default     = null
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
    error_message = "Memory must be from 128 to 4096 megabytes."
  }
}

variable "execution_timeout" {
  description = "Execution timeout in seconds for cloud function yc-function-example."
  type        = number
  default     = 10
}

variable "source_path" {
  description = "The absolute path to a local file or directory of the Function's source code."
  type        = string
  default     = null
}

variable "zip_filename" {
  description = "The absolute path to the `.zip` archive of the Function's source code."
  type        = string
  default     = null
}

variable "scaling_policy" {
  description = "List of scaling policies for cloud function yc-function-example."
  type = list(object({
    tag                  = string
    zone_instances_limit = number
    zone_requests_limit  = number
  }))
}

# ##############################################################################
# Function-specific resources                                                   
# ##############################################################################

variable "public_access" {
  description = "Making cloud function public (true) or not (false)."
  type        = bool
  default     = false
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

variable "lockbox_secret_key" {
  description = "Lockbox secret key for cloud function yc-function-example."
  type        = string
}

variable "lockbox_secret_value" {
  description = "Lockbox secret value for cloud function yc-function-example."
  type        = string
}

# ##############################################################################
# Function trigger                                                              
# ##############################################################################

variable "choosing_trigger_type" {
  description = "Choosing type for cloud function trigger."
  type        = string
  validation {
    condition     = contains(["logging", "timer", "object_storage", "message_queue", ""], var.choosing_trigger_type)
    error_message = "Trigger type should be logging, timer, object_storage, message_queue or empty string."
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

variable "network_id" {
  description = "Cloud function's network id for VPC integration."
  type        = string
  default     = null # "enp9rm1debn7usfmtlnv"
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

variable "environment_variable" {
  description = "Function's environment variable in which secret's value will be stored."
  type        = string
  default     = "ENV_VARIABLE"
}

variable "use_async_invocation" {
  description = "Use asynchronous invocation to message queue (true) or not (false). If `true`, parameters `ymq_success_target` and `ymq_failure_target` must be set."
  type        = bool
  default     = false
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