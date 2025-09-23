defmodule BrowsergridWeb.API.V1.EdgeDebugJSON do
  def index(%{data: data}) do
    %{
      success: true,
      data: data
    }
  end

  def lookup(%{data: data}) do
    %{
      success: true,
      data: data
    }
  end

  def sync(%{data: data}) do
    %{
      success: true,
      data: data
    }
  end
end
