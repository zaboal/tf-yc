output "function_id" {
  description = "Yandex cloud function ID."
  value       = yandex_function.this.id
}

output "function_name" {
  description = "Yandex cloud function name."
  value       = yandex_function.this.name
}
