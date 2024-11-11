defmodule ShowScorerTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Scorer.Show
  
  defp suit_generator() do
    gen all suit <- one_of([constant(:hearts), constant(:diamonds), constant(:clubs), constant(:spades)]) do
      suit
    end
  end

  defp rank_generator() do
    gen all rank <- one_of([constant(:two), constant(:three), constant(:four), constant(:five), constant(:six), constant(:seven), constant(:eight), constant(:nine), constant(:ten), constant(:jack), constant(:queen), constant(:king), constant(:ace)]) do
      rank
    end
  end

  defp card_generator() do
    gen all suit <- suit_generator(),
            rank <- rank_generator() do
      [rank, suit]
    end
  end

  describe "pair scoring" do
    property "pairs result in total hand score > 0" do
      check all hand <- list_of(card_generator(), length: 5) do
        contains_pairs =
          hand
          |> Enum.group_by(&Card.rank/1)
          |> Enum.any?(fn {_, cards} -> Enum.count(cards) == 2 end)
        if contains_pairs do
          assert Show.score(hand) > 0
        end 
      end
    end
  end

  describe "flush scoring" do
    property "flushes result in total hand score > 0" do
      check all suit <- suit_generator(),
                cards <- list_of(rank_generator(), length: 5),
                hand = Enum.map(cards, fn c -> [c, suit] end) do
        assert Show.score(hand) > 0
      end
    end
  end

  
end
