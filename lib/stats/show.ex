defmodule Stats.Show  do
  @moduledoc """
  Documentation for `CribbageScorer`.
  """

  def new() do
    {:stats, []}
  end
  def new(hand) do
    {:stats, [hand: hand]}
  end

  # Combinatoric helpers
  def possible_hands(hand) do
    Combinatorics.n_combinations(4, hand) 
  end

  def hand_with_cut_card_scores(hand, deck) do
    deck
    |> Enum.map(fn cut_card -> {cut_card, Scorer.Show.score([cut_card | hand])} end)
  end

  def hand_scores({:stats, data}) do
    d = Enum.reject(Deck.new(), fn x -> Enum.member?(data[:hand], x) end)
    all_scores = 
      data[:hand]
      |> possible_hands
      |> Task.async_stream(
        fn a_hand -> %{hand: a_hand, scores: hand_with_cut_card_scores(a_hand, d)} end)
      |> Enum.map(
          fn {:ok, %{hand: h, scores: s}} -> 
            total = Enum.count(s)
            scores = 
              s
              |> Enum.group_by(fn {_, score} -> score end, fn {cut_card, _} -> cut_card end)
              |> Enum.into(%{}, 
                fn {score, cards} -> {score, %{probability: Enum.count(cards) / total, cut_cards: cards}} end)

            Enum.reduce(scores, %{keeping: h, scoring: scores, mean: 0, max: 0, min: 29, median: []},
                fn {score, %{probability: p, cut_cards: cc}}, acc -> 
                  acc
                  |> Map.update!(:mean, fn x -> x + score * p end)
                  |> Map.update!(:max, fn x -> if x < score, do: score, else: x end)
                  |> Map.update!(:min, fn x -> if x > score, do: score, else: x end)
                  |> Map.update!(:median, fn x -> Enum.concat(x, Stream.repeatedly(fn -> score end) |> Enum.take(Enum.count(cc))) end)
                end)
            |> Map.update!(:median, fn median ->
              median
              |> Enum.sort
              |> Enum.drop(if rem(total, 2) == 0, do: div(total, 2), else: div(total, 2) - 1)
              |> List.first()
              end)
        end)
    {:stats, Keyword.put(data, :scores, all_scores)}
  end

  def hand_scores(hand) do
    hand_scores(new(hand))
  end

  

  def crabalab(comparator, {standard, standard_value}, {replacement, replacement_value}) do
    cond do
      standard == replacement ->
        {standard, [replacement_value | standard_value]}
      comparator.(standard, replacement) ->
        {replacement, [replacement_value]}
      true ->
        {standard, standard_value}
    end
  end

  
  def hand_stats({:stats, data}) do
    hand_variants = Enum.count(data)
    score_stats =
      data[:scores]
      |> Enum.reduce(
        %{best_mean_score: {0, []}, 
          worst_mean_score: {29,[]}, 
          max_score: {0,[]}, 
          min_score: {29,  []},
          best_median_score: {0, []},
          worst_median_score: {29, []}
        }, 
        fn s, acc ->
          Map.update!(acc, :best_mean_score, 
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:mean], s[:keeping]}) end)
          |> Map.update!(:worst_mean_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:mean], s[:keeping]}) end)
          |> Map.update!(:max_score, 
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:max], s[:keeping]}) end)
          |> Map.update!(:min_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:min], s[:keeping]}) end)
          |> Map.update!(:best_median_score, 
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:median], s[:keeping]}) end)
          |> Map.update!(:worst_median_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:median], s[:keeping]}) end)
        end)
    {:stats, Keyword.put(data, :stats, score_stats)}
  end
  def hand_stats(hand) do
    hand_stats(hand_scores(hand))
  end

  # Selectors
  def select_hand_stat({:stats, data}, :all) do
    data[:stats]
  end
  def select_hand_stat({:stats, data}, stat) do
    data[:stats][stat] |> elem(0)
  end
  def select_hand_stat(hand, stat) do
    select_hand_stat(hand_stats(hand), stat)
  end

  def best_mean_score(data), do: select_hand_stat(data, :best_mean_score)
  def worst_mean_score(data), do: select_hand_stat(data, :worst_mean_score)
  def max_score(data), do: select_hand_stat(data, :max_score)
  def min_score(data), do: select_hand_stat(data, :min_score)
  def best_median_score(data), do: select_hand_stat(data, :best_median_score)
  def worst_median_score(data), do: select_hand_stat(data, :worst_median_score)

  def select_hands_with({:stats, data}, selection) do
    filtered = Enum.filter(data[:scores], fn s -> Enum.all?(selection, fn x -> Enum.member?(x, s[:keeping]) end) end)
    if Enum.count(filtered) == 0 do
      %{error: "Hand not found"}
    else
      filtered
    end
  end
  def select_hands_with({:error, e}, _), do: {:error, e}
  def select_hands_with(selection, hand), do: select_hands_with(hand_stats(hand), selection)
  
  def where({:stats, data}, filters \\ []) do
    {:stats, Keyword.update!(data, :scores, fn scores -> Enum.reduce(filters, scores, &where_helper/2) end)}
  end
  def where(hand, filters), do: where(hand_stats(hand), filters)

  defp where_helper({:cards, cards}, scores) do
    Enum.filter(scores, fn s -> Enum.all?(cards, fn c -> Enum.any?(s[:keeping], &Card.same_card?(c, &1)) end) end)
  end
  defp where_helper({:score, {comparator, score}}, scores) do
    case comparator do
      :gt -> where_score_helper({:score, {&>/2, score}}, scores)
      :gte -> where_score_helper({:score, {&>=/2, score}}, scores)
      :lt -> where_score_helper({:score, {&</2, score}}, scores)
      :lte -> where_score_helper({:score, {&<=/2, score}}, scores)
      :ne -> where_score_helper({:score, {&!=/2, score}}, scores)
      :eq -> where_score_helper({:score, {&==/2, score}}, scores)
      _ -> scores
    end
  end
  defp where_helper({:score, score}, scores), do: where_score_helper({:score, {:eq, score}}, scores)

  defp where_score_helper({:score, {comparator, score}}, scores) do
    Enum.reduce(scores, [], 
      fn s, acc ->
        new_scoring = Enum.filter(s[:scoring], fn {sc, _} -> comparator.(sc, score) end)
        if Enum.count(new_scoring) > 0 do
          [Map.update!(s, :scoring, fn _ -> new_scoring end) | acc]
        else
          acc
        end
      end)
  end

  def select({:stats, data}, selectors \\ []) do
    Enum.reduce(selectors, data[:scores], &select_helper/2)
  end
  def select(hand, selectors), do: select(hand_stats(hand), selectors)

  defp select_helper(:hand, scores) do
    Enum.map(scores, fn s -> s[:keeping] end)
  end
  defp select_helper(:scores, scores) do
    Enum.map(scores, fn s -> s[:scoring] end)
  end
  defp select_helper(:mean, scores) do
    Enum.map(scores, fn s -> s[:mean] end)
  end
  defp select_helper(:max, scores) do
    Enum.map(scores, fn s -> s[:max] end)
  end
  defp select_helper(:min, scores) do
    Enum.map(scores, fn s -> s[:min] end)
  end
  defp select_helper(:median, scores) do
    Enum.map(scores, fn s -> s[:median] end)
  end


  defp scoring_stats_given_hand(selection, stat, {:stats, data}) do
    data[:scores]
    |> Enum.find(%{error: "Hand not found"}, &(Enum.sort(&1[:hand]) == Enum.sort(selection)))
    |> Map.get(:scoring_stats, %{error: "Hand not found"})
    |> Map.get(stat, %{error: "Hand not found"})
  end
  defp scoring_stats_given_hand(selection, stat) do
    scoring_stats_given_hand(selection, stat, hand_stats(selection))
  end

  defp stat_given_hand(stat, selection, f_h) do
    f_h
    |> Enum.find(%{error: "Hand not found"}, &(Enum.sort(&1[:hand]) == Enum.sort(selection)))
    |> Map.get(:scoring_stats, %{error: "Hand not found"})
    |> Map.get(stat, %{error: "Hand not found"})
  end
  defp stat_given_hand(stat, selection) do
    stat_given_hand(stat, selection, hand_stats(selection))
  end

  def mean_given_hand(selection, %{scores: scores}) do
    stat_given_hand(:mean_score, selection, scores)
  end

  def max_given_hand(selection, %{scores: scores}) do
    stat_given_hand(:max_score, selection, scores)
  end

  def min_given_hand(selection, %{scores: scores}) do
    stat_given_hand(:min_score, selection, scores)
  end

  def median_given_hand(selection, %{scores: scores}) do
    stat_given_hand(:median_score, selection, scores)
  end

  def probability_of_score_given_hand(score, given, hand) do
    probability_of_score_given_hand(score, given, hand, hand_stats(hand))
  end
  def probability_of_score_given_hand(score, given, hand, hand_stats) do
    hand_stats.scores
      |> Enum.find(%{error: "Hand not found"}, &(Enum.sort(&1[:hand]) == Enum.sort(given)))
      |> Map.get(:scores, %{error: "Hand not found"})
      |> Map.get(score, %{error: "Score for hand not found"})
      |> Map.get(:probability)
  end

end


