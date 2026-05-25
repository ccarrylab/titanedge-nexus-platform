package kubernetes

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg = sprintf("Deployment %v: container %v missing memory limit", [input.metadata.name, container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg = sprintf("Deployment %v: container %v missing CPU limit", [input.metadata.name, container.name])
}
