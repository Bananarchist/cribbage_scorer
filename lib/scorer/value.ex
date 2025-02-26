defmodule Scorer.Value do
  def of_card(card) do
    case Card.rank(card) do
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
end
