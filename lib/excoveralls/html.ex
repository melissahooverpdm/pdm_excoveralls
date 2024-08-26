defmodule ExCoveralls.Html do
  @moduledoc """
  Generate HTML report of result.
  """

  alias ExCoveralls.Html.View
  alias ExCoveralls.Stats

  @file_name "excoveralls.html"

  def team_percentages(test_type) do
    "./cover/#{test_type}/test_coverage_percent_by_teams.json"
  end

  def coverage_json_path(test_type) do
    "./cover/#{test_type}/detailed_test_coverage.json"
  end

  def read_json_file(filename) do
    with {:ok, body} <- File.read(filename) do
      Jason.decode(body)
    end
  end

  @doc """
  Provides an entry point for the module.
  """
  def execute(stats, options \\ []) do
    ExCoveralls.Local.print_summary(stats)

    options = ConfServer.get()

    type =  options[:type]

    if is_nil(type) do
      Stats.source(stats, options[:filter]) |> generate_report(options[:output_dir])
    else
      type =  options[:type]
      team_percentages_json_path =  options[:team_percentages_json_path]

      with {:ok, detailed_coverage_json} <- read_json_file(coverage_json_path(type)),
           {:ok, team_percentages_json} <- read_json_file(team_percentages(type)) do
          Enum.each(detailed_coverage_json, fn %{"ownership" => ownership, "test_coverage" => test_coverage} ->

            output_dir = "./cover/#{type}/#{ownership}"

            if File.dir?(output_dir) == false do
              File.mkdir!(output_dir)
            end

            files = Enum.map(test_coverage, fn item ->
              item["file_path"]
            end)

            team_stats =
              stats
              |> Enum.filter(fn stat ->
                Enum.member?(files, stat.name)
              end)
              |> Enum.map(fn stat ->
                Map.put(stat, "ownership", ownership)
              end)

            %{"ownership" => _owner, "test_coverage" => team_percentage} = Enum.find(team_percentages_json, fn %{"ownership" => owner} -> owner == ownership end)

            Stats.source(team_stats, options[:filter]) |> generate_report(output_dir, ownership, team_percentage)
          end)
      end
    end

    Stats.ensure_minimum_coverage(stats)
  end

  defp generate_report(map, output_dir, ownership, team_percentage) do
    IO.puts("Generating report...")

    filter_full_covered =
      Map.get(ExCoveralls.Settings.get_coverage_options(), "html_filter_full_covered", false)

    map = map
      |> Map.put(:team_percentage, team_percentage)
      |> Map.put(:ownership, String.upcase(ownership))

    View.render(cov: map, filter_full_covered: filter_full_covered) |> write_file(output_dir)
  end

  defp output_dir(output_dir) do
    cond do
      output_dir ->
        output_dir
      true ->
        options = ExCoveralls.Settings.get_coverage_options()
        case Map.fetch(options, "output_dir") do
          {:ok, val} -> val
          _ -> "cover/"
        end
    end
  end

  defp write_file(content, output_dir) do
    file_path = output_dir(output_dir)
    unless File.exists?(file_path) do
      File.mkdir_p!(file_path)
    end

    File.write!(Path.expand(@file_name, file_path), content)
    IO.puts "Saved to: #{file_path}"
  end
end
