defmodule BzDeploy do
  defstruct [
    image_name: "image",
    image_tag: "latest",
    kustomization_file: "kustomization.yaml",
    kube_context: "default",
    skip_build: false
  ]

  def run(config \\ %__MODULE__{}) do
    # Change to the directory of the script
    File.cd!(Path.dirname(__ENV__.file))

    digest = if config.skip_build do
      IO.puts "\e[1mSkipping build step...\e[0m"
      get_existing_digest(config)
    else
      build_and_push_image(config)
    end

    IO.puts "\e[1mdeploying \e[32m#{digest}\e[0m"

    manifests = Path.join(System.tmp_dir!(), "manifests-#{String.slice(digest, -7..-1)}")
    IO.puts "patched manifests copied to \e[33m#{manifests}\e[0m"

    File.cp_r!("manifests", manifests)

    update_yaml(manifests, digest, config)

    apply_manifests(manifests, config)

    IO.puts "\e[1mcleaning up\e[0m"
    File.rm_rf!(manifests)
  end

  defp build_and_push_image(config) do
    image = "#{config.image_name}:#{config.image_tag}"
    IO.puts "\e[1mbuilding image...\e[0m"
    {_, 0} = System.cmd("docker", ["build", ".", "--platform=linux/arm64", "-t", image, "--push"], into: IO.stream(:stdio, :line))
    get_existing_digest(config)
  end

  defp get_existing_digest(config) do
    image = "#{config.image_name}:#{config.image_tag}"
    {image, 0} = System.cmd("docker", ["inspect", "--format={{index .RepoDigests 0}}", image])
    image
    |> String.trim()
    |> String.split("@")
    |> List.last()
  end

  defp update_yaml(manifests, digest, config) do
    kustomization_path = Path.join(manifests, config.kustomization_file)
    {:ok, kustomization} = YamlElixir.read_from_file(kustomization_path)

    updated_kustomization =
      put_in(kustomization, ["images", Access.at(0)], %{
        "digest" => digest,
        "name" => config.image_name,
        "newName" => config.image_name,
        "newTag" => config.image_tag
      })

    json_content = Jason.encode!(updated_kustomization, pretty: true)
    File.write!(kustomization_path, json_content)
  end

  defp apply_manifests(manifests, config) do
    # Generate the final YAML using kustomize
    {yaml, 0} = System.cmd("kustomize", ["build", manifests])

    # Parse the YAML into a list of Kubernetes resources
    resources =
      yaml
      |> String.split("---")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&YamlElixir.read_from_string!/1)

    # Initialize the Kubernetes client with the OCI context
    {:ok, conn} = K8s.Conn.from_file("~/.kube/config", context: config.kube_context)

    results =
      conn
      |> K8s.Client.Runner.Async.run(for(resource <- resources, do: K8s.Client.apply(resource)))

    for result <- results do
      case result do
        {:ok, resource} -> IO.puts "Successfully applied resource: #{resource["kind"]}/#{resource["metadata"]["name"]}"
        {:error, reason} -> IO.puts "Failed to apply resource: #{inspect(reason)}"
      end
    end
  end
end
