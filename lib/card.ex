defmodule Card do

  def ranks do
    [:two, :three, :four, :five, :six, :seven, :eight, :nine, :ten, :jack, :queen, :king, :ace]
  end

  def suits do
    [:hearts, :diamonds, :clubs, :spades]
  end

  def suit([_ | suit]) do
    suit
  end
  def suit({_, suit}) do
    suit
  end

  def rank([rank | _]) do
    rank
  end
  def rank({rank, _}) do
    rank
  end

  def ordinal(card) do
    case rank(card) do
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

  def same_rank?(card1, card2) do
    rank(card1) == rank(card2)
  end

  def same_suit?(card1, card2) do
    suit(card1) == suit(card2)
  end

  def same_card?(card1, card2) do
    same_rank?(card1, card2) && same_suit?(card1, card2)
  end
end
