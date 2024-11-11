defmodule Deck do
  
  def new do
    for suit <- Card.suits(), rank <- Card.ranks() do
      [rank, suit]
    end
  end

  def draw(count \\ 1, deck \\ new()) do
    Enum.take_random(deck, count)
  end

  def deal(count \\ 6, deck \\ new()) do
    hand = draw(count, deck)
    remaining = Enum.reject(deck, fn card -> card in hand end)
    {hand, remaining}
  end
end
