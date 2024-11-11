defmodule Stats.Show  do
  @moduledoc """
  Documentation for `CribbageScorer`.
  """

  # Combinatoric helpers
  def possible_hands(hand) do
    Combinatorics.n_combinations(4, hand) 
  end

  def hand_with_cut_card_scores(hand, deck) do
    deck
    |> Enum.map(fn cut_card -> {cut_card, Scorer.Show.score([cut_card | hand])} end)
  end

  def all_show_scores(hand) do
    d = Enum.reject(Deck.new(), fn x -> Enum.member?(hand, x) end)
    hand
    |> possible_hands
    |> Task.async_stream(fn a_hand -> %{hand: a_hand, scores: hand_with_cut_card_scores(a_hand, d)} end)
  end

  def show_scores_grouped_by_points(hand) do
    show_scores_grouped_by_points(hand, all_show_scores(hand))
  end
  def show_scores_grouped_by_points(_hand, scores) do
    Enum.map(scores, fn {:ok, %{hand: h, scores: s}} -> 
      scores = Enum.group_by(s, fn {_, score} -> score end, fn {cut_card, _} -> cut_card end)
      %{hand: h, scores: scores}
      end)
  end

  def grouped_scores_with_probabilities(hand) do
    grouped_scores_with_probabilities(hand, show_scores_grouped_by_points(hand))
  end

  def grouped_scores_with_probabilities(_hand, scores) do
    Enum.map(scores, fn %{hand: h, scores: s} -> 
      total = Map.values(s) |> Enum.concat |> Enum.count
      new_scores = Enum.into(s, %{}, fn {score, cards} -> {score, %{probability: Enum.count(cards) / total, cut_cards: cards}} end)
      %{hand: h, scores: new_scores}
      end)
  end
  
  def grouped_scores_with_stats(hand) do
    grouped_scores_with_stats(hand, grouped_scores_with_probabilities(hand))
  end

  def grouped_scores_with_stats(_hand, scores) do
    scores
    |> Enum.map(&Map.put(&1, :scoring_stats, %{})) 
    |> grouped_scores_with_mean
    |> grouped_scores_with_max
    |> grouped_scores_with_min
    |> grouped_scores_with_median
  end

  def grouped_scores_with_mean(scores) do
    averages = 
      scores
      |> Enum.map(fn %{scores: s} -> 
          Enum.map(s, fn {score, data} -> data[:probability] * score end)
          |> Enum.reduce(0, fn x, acc -> x + acc end)
        end)
    Enum.zip_with([scores, averages], fn [s, a] -> Map.update!(s, :scoring_stats, &Map.put(&1, :mean_score, a)) end)
  end

  def grouped_scores_with_max(scores) do
    maxes =
      scores
      |> Enum.map(fn data ->
          Enum.map(data[:scores], fn {score, _} -> score end)
          |> Enum.reduce(0, fn x, acc -> if x > acc, do: x, else: acc end)
        end)
    Enum.zip_with([scores, maxes], fn [s, a] -> Map.update!(s, :scoring_stats, &Map.put(&1, :max_score, a)) end)
  end

  def grouped_scores_with_min(scores) do
    minimums =
      scores
      |> Enum.map(fn %{scores: s} -> 
          Enum.map(s, fn {score, data} -> score end)
          |> Enum.reduce(29, fn x, acc -> if x < acc, do: x, else: acc end)
        end)
    Enum.zip_with([scores, minimums], fn [s, a] -> Map.update!(s, :scoring_stats, &Map.put(&1, :min_score, a)) end)
  end

  def grouped_scores_with_median(scores) do
    medians =
      scores
      |> Enum.map(fn %{scores: s} -> 
          s2 =
            Enum.flat_map(s, fn {score, data} -> Enum.map(data[:cut_cards], fn _ -> score end) end)
            |> Enum.sort()
          length = Enum.count(s2)
          if rem(length, 2) == 0 do
            (Enum.at(s2, div(length, 2) - 1) + Enum.at(s2, div(length, 2))) / 2
          else
            Enum.at(s2, div(length, 2))
          end
      end)
    Enum.zip_with([scores, medians], fn [s, a] -> Map.update!(s, :scoring_stats, &Map.put(&1, :median_score, a)) end)
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

  def for_hand(hand) do
    for_hand(hand, grouped_scores_with_stats(hand))
  end
  
  def for_hand(hand, grouped_scores_and_stats) do
    hand_variants = Enum.count(grouped_scores_and_stats)
    score_stats =
      grouped_scores_and_stats
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
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:scoring_stats][:mean_score], s[:hand]}) end)
          |> Map.update!(:worst_mean_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:scoring_stats][:mean_score], s[:hand]}) end)
          |> Map.update!(:max_score, 
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:scoring_stats][:max_score], s[:hand]}) end)
          |> Map.update!(:min_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:scoring_stats][:min_score], s[:hand]}) end)
          |> Map.update!(:best_median_score, 
            fn {x, xh} -> crabalab(&</2, {x, xh}, {s[:scoring_stats][:median_score], s[:hand]}) end)
          |> Map.update!(:worst_median_score, 
            fn {x, xh} -> crabalab(&>/2, {x, xh}, {s[:scoring_stats][:median_score], s[:hand]}) end)
        end)
    %{hand: hand, scores: grouped_scores_and_stats, score_stats: score_stats}
  end
end
