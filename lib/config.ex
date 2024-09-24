defmodule BzDeploy.Config do
  defstruct image_name: "image",
            image_tag: "latest",
            kustomization_file: "kustomization.yaml",
            kube_context: "default",
            skip_build: false
end
