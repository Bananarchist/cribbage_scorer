defmodule CribbageScorer do
  @moduledoc """
  Documentation for `CribbageScorer`.
  """



  # Inititalization
  def deck() do
    a = [:hearts, :diamonds, :clubs, :spades]
    b = [:ace, :two, :three, :four, :five, :six, :seven, :eight, :nine, :ten, :jack, :queen, :king]
    Combinatorics.product([a, b])
  end
  def draw() do
    hand = Enum.take_random(deck(), 6)
    {hand, Enum.filter(deck(), fn x -> not Enum.member?(hand, x) end)}
  end


  # Combinatoric helpers
  def testable_combinations(hand) do
    hand
    |> Combinatorics.powerset
    |> Enum.filter(fn x -> length(x) >= 2 end)
  end

  def possible_hands(hand) do
    Combinatorics.n_combinations(4, hand) 
  end

  # Show testing
  def calculate_probable_score() do
    {hand, deck} = draw()
    {hand, calculate_probable_score_for_given_hand(hand, deck)}
  end
  def calculate_probable_score_for_given_hand(hand) do
    calculate_probable_score_for_given_hand(hand, Enum.filter(deck(), fn x -> not Enum.member?(hand, x) end))
  end
  def calculate_probable_score_for_given_hand(hand, deck) do
    # problem: hand equality is tested at least once (Enum.group_by/2) which is order-dependent on lists
    deck_length = Enum.count(deck)
    Combinatorics.product([deck, possible_hands(hand)])
    |> Enum.map(fn [cut_card | [a_hand | [] ]] -> {a_hand, cut_card, score([cut_card | a_hand])} end)
    |> Enum.group_by(fn {a_hand, _, _} -> a_hand end)
    |> Enum.map(fn {a_hand, scores} -> 
      {avg, macks} = Enum.reduce(scores, {0, {[], 0}}, 
        fn {_, cut_card, score}, {avg, {cc, macks}} -> 
          {(score / deck_length) + avg,
          cond do
            score > macks -> {[cut_card], score}
            score == macks -> {[cut_card | cc], macks}
            true -> {cc, macks}
          end
          }
        end)
        %{"hand" => a_hand, "average" => avg, "max" => macks}
      end)  
      |> Enum.sort_by(&(&1["average"]))
    end


  # Scoring
  
  # needs to account for other players' draws
  def score(hand) do
    fifteen_points(hand) + nobs_points(hand) + pairs_points(hand) + flush_points(hand) + straight_points(hand)
  end
  def card_value([_suit| [ card | []]]) do
    case card do
      :ace -> 1
      :two -> 2
      :three -> 3
      :four -> 4
      :five -> 5
      :six -> 6
      :seven -> 7
      :eight -> 8
      :nine -> 9
      :ten -> 10
      :jack -> 10
      :queen -> 10
      :king -> 10
    end
  end
  def ordinal([_suit| [ card | []]]) do
    case card do
      :ace -> 1
      :two -> 2
      :three -> 3
      :four -> 4
      :five -> 5
      :six -> 6
      :seven -> 7
      :eight -> 8
      :nine -> 9
      :ten -> 10
      :jack -> 11
      :queen -> 12
      :king -> 13
    end
  end
    

  def equals_to_15?(cards) do
    Enum.reduce(cards, 0, fn card, acc -> acc + card_value(card) end) == 15
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
  def is_nobs?([suit | [:jack | []]], [cut_card_suit | _]) do
    suit == cut_card_suit
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
    |> Enum.group_by(fn [_ | [val | []]] -> val end)
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
  def flush_points([[cut_card_suit | _] | hand]) do
    suits = Enum.uniq_by(hand, fn [suit| _] -> suit end) 
    cond do
      Enum.all?(hand, fn [suit| _] -> suit == cut_card_suit end) -> 5
      length(suits) == 1 -> 4
      true -> 0
    end
  end
  def straight_points(hand) do
    {longest_straight, doubles} = hand
    |> Enum.map(&ordinal/1)
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
