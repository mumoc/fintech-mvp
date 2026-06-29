module Countries
  module MX
    # MX status state machine. The AASM transition graph is implemented in T009;
    # this anchors the registry contract and the initial state for now.
    class StateMachine < Base::StateMachine
      INITIAL_STATE = "received".freeze
    end
  end
end
