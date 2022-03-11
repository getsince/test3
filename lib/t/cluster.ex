defmodule T.Cluster do
  @moduledoc false

  @spec poll_ec2(String.t(), [String.t()]) :: [ip_address :: String.t()]
  def poll_ec2(name, regions) do
    # maybe use vpc-id per region as well?

    request =
      ExAws.EC2.describe_instances(
        filters: [
          {"tag:Name", name},
          {"instance-state-name", "running"}
        ]
      )

    xpath = private_ip_address_xpath()

    regions
    |> Enum.map(fn region ->
      {:ok, %{body: body}} = ExAws.request(request, region: region)
      body |> SweetXml.xpath(xpath) |> Enum.uniq()
    end)
    |> List.flatten()
  end

  defp private_ip_address_xpath do
    import SweetXml, only: [sigil_x: 2]

    ~x"//DescribeInstancesResponse/reservationSet/item/instancesSet/item/privateIpAddress/text()"ls
  end
end
