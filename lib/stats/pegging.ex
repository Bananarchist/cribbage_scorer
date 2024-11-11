defmodule Stats.Pegging do
  def play_tree([lead_hand | follow_hands]) do
    passes_remaining = length(follow_hands) + 1
    current_player = new_player_struct(lead_hand)
    remaining_players = Enum.map(follow_hands, &new_player_struct/1)
    lead_hand
    |> Enum.group_by(&Function.identity/1)
    |> Enum.map(fn {card, _cards} -> 
      {card, 
        { scores_of_player_structs([current_player | remaining_players]),
          play_tree(passes_remaining, [card], remaining_players, 
            [Map.update!(current_player, "hand", fn current_hand -> 
              Enum.filter(current_hand, fn c -> c != card 
              end) 
            end)] 
          )}}
    end)
    |> Map.new()
  end

  def new_player_struct(hand) do
    %{"hand" => hand, "score" => 0}
  end

  def scores_of_player_structs(player_structs) do
    Enum.map(player_structs, fn player -> player["score"] end)
  end
  # handle restarting order
  def play_tree(passes_remaining, cards_played, [], previous_players) do
    play_tree(passes_remaining, cards_played, Enum.reverse(previous_players), [])
  end

  # handle no remaining passes
  def play_tree(0, cards_played, [current_player | remaining_players], previous_players) do
    # no cards remaining in any hand
    if Enum.reduce([current_player | previous_players] ++ remaining_players, 0, fn p, acc -> Enum.count(p["hand"]) + acc end) |> Kernel.==(0) do

      :ok
    # someone has cards left, but no one can play <31
    # reset the passes and start at next hand
    else
      play_tree(length(remaining_players) + length(previous_players) + 1, [], remaining_players, [current_player | previous_players])
    end
  end

  # no cards remaining in next hand: decrement passes and proceed to next player
  def play_tree(passes_remaining, cards_played, [current_score | next_score], previous_scores, [[] | next_hands], previous_hands) do
    play_tree(passes_remaining - 1, cards_played, next_score, [current_score | previous_scores], next_hands, [[] | previous_hands])
  end

  # handle playing cards
  def play_tree(passes_remaining, cards_played, [current_player | remaining_players], previous_players) do
    current_value = Enum.reduce(cards_played, 0, fn card, acc -> acc + Scorer.Value.of_card(card) end)
    playable_cards = Enum.filter(current_player["hand"], fn card -> Scorer.Value.of_card(card) + current_value <= 31 end)
    cond do
      length(playable_cards) == 0 ->
        # no playable cards => pass
        play_tree(passes_remaining - 1, cards_played, remaining_players, [current_player | previous_players])
      true ->
        Enum.group_by(playable_cards, &Function.identity/1)
        |> Enum.map(fn {card, _} -> 
          new_cards_played = [card | cards_played]
          new_player = 
            Map.update!(current_player, "hand", fn current_hand ->
              Enum.filter(current_hand, fn c -> c != card end)
            end)
            |> Map.update!("score", fn current_score -> current_score + Scorer.Pegging.score([card | cards_played]) end)
          new_scores = scores_of_player_structs(Enum.reverse(previous_players) ++ [new_player | remaining_players])
           {card, {new_scores, play_tree(Enum.count(new_scores), new_cards_played, remaining_players, [new_player | previous_players])}}
          end)
        |> Map.new()
    end
  end

end
