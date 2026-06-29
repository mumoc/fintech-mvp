module Countries
  module Base
    # Marker base for a country's status state machine. The AASM wiring and the
    # per-country transition graph land in T009 (state machine + status update);
    # for now it only anchors the registry contract.
    class StateMachine
    end
  end
end
