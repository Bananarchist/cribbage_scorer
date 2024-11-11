defmodule Scorer.Show do

  def score(hand) do
    fifteen_points(hand) + nobs_points(hand) + pairs_points(hand) + flush_points(hand) + straight_points(hand)
  end

  def testable_combinations(hand) do
    hand
    |> Combinatorics.powerset
    |> Enum.filter(fn x -> length(x) >= 2 end)
  end

  def equals_to_15?(cards) do
    Enum.reduce(cards, 0, fn card, acc -> acc + Scorer.Value.of_card(card) end) == 15
  end
  def fifteen_points(cards) do
    cards
    |> testable_combinations
    |> Enum.count(&equals_to_15?/1)
    |> Kernel.*(2)
  end
  def hand_has_nobs?([cut_card | hand]) do
    Enum.any?(hand, fn card -> is_nobs?(card, cut_card) end)
  end
  def is_nobs?([:jack | [suit | []]], cut_card) do
    suit == Card.suit(cut_card)
  end
  def is_nobs?(_, _) do
    false
  end
  def nobs_points(hand) do
    if hand_has_nobs?(hand) do
      1
    else
      0
    end
  end
  def pairs_points(hand) do
    hand
    |> Enum.group_by(&List.first/1)
    |> Enum.filter(fn {_, cards} -> length(cards) >= 2 end)
    |> Enum.map(fn {_, cards} -> 
      case length(cards) do
        2 -> 2
        3 -> 6
        4 -> 12
      end
    end)
    |> Enum.sum()
  end
  def flush_points([cut_card | hand]) do
    suits = Enum.uniq_by(hand, &Card.suit/1)
    cond do
      Enum.all?(hand, fn c -> Card.suit(c) == Card.suit(cut_card) end) -> 5
      length(suits) == 1 -> 4
      true -> 0
    end
  end
  def straight_points(hand) do
    {longest_straight, doubles} = hand
    |> Enum.map(&Card.ordinal/1)
    |> Enum.sort()
    |> Enum.reduce([], fn card, straights ->
      case straights do
        [] -> [{[card], 0}]
        [current | others] ->
          {last_straight, doubles} = current
          [last_card | _] = last_straight
          if card == last_card + 1 do
            [{[card | last_straight], doubles} | others]
          else if card == last_card do
            [{last_straight, doubles + 1} | others]
          else
            [{[card], 0} | [current | others]]
          end
        end
      end
    end)
    |> Enum.max_by(fn {straight, _} -> length(straight) end)
    
    if length(longest_straight) >= 3 do
      length(longest_straight) * (doubles + 1)
    else
      0
    end
    
    
  end
end
