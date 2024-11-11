defmodule Scorer.Pegging do
  def score(hand) do
    score(hand, [])
  end
  def score(hand, cut_card) do
    nibs(cut_card) + fifteen_points(hand) + pairs_points(hand) + straight_points(hand)
  end

  def nibs(cut_card) do
    case Card.rank(cut_card) do
      :jack -> 2
      _ -> 0
    end
  end

  def fifteen_points(hand) do
    if Enum.reduce(hand, 0, fn card, acc -> acc + Scorer.Value.of_card(card) end) == 15 do
      2
    else
      0
    end
  end

  def pairs_points(cards) do
    case cards
      |> Enum.reduce_while(nil, fn card, acc ->
        val = Card.rank(card)
        case acc do
          nil -> {:cont, {val, 1}}
          {last, count} -> if last == val do
            {:cont, {val, count + 1}}
          else
            {:halt, {val, count}}
          end
        end
      end)
      |> elem(1)
    do
      2 -> 2
      3 -> 6
      4 -> 12
      _ -> 0
    end
  end

  def straight_points([last | cards]) do
    if length(cards) < 2 do
      0
    else
      # duplicates are to be removed
      # remaining length = n
      # all cards must be within n-1 of the most recently played card
      # 
      straights =
        3..Enum.count([last | cards])
        |> Enum.map(fn count ->
          [last | cards]
          |> Enum.map(&Card.ordinal/1)
          |> Enum.take(count)
          |> Enum.uniq()
          |> Enum.sort()
        end)
        |> Enum.filter(fn [lowest | remainder] ->
          remainder_count = Enum.count(remainder)
          lowest + Enum.sum(remainder) == lowest + (lowest * remainder_count) + Enum.sum(1..remainder_count)
          end)
      if length(straights) > 0 do
        Enum.max_by(straights, &Enum.count/1)
        |> Enum.count()
      else
        0
      end
        
    end
  end

end
