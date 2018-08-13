require "../protocol"

module FIX
  class Protocol4_4 < Protocol
    @messageTypes = {
      :Heartbeat                              => "0",
      :ResendRequest                          => "2",
      :SequenceReset                          => "4",
      :IOI                                    => "6",
      :ExecutionReport                        => "8",
      :Logon                                  => "A",
      :NewOrderMultileg                       => "AB",
      :TradeCaptureReportRequest              => "AD",
      :OrderMassStatusRequest                 => "AF",
      :RFQRequest                             => "AH",
      :QuoteResponse                          => "AJ",
      :PositionMaintenanceRequest             => "AL",
      :RequestForPositions                    => "AN",
      :PositionReport                         => "AP",
      :TradeCaptureReportAck                  => "AR",
      :AllocationReportAck                    => "AT",
      :SettlementInstructionRequest           => "AV",
      :CollateralRequest                      => "AX",
      :CollateralResponse                     => "AZ",
      :CollateralReport                       => "BA",
      :NetworkCounterpartySystemStatusRequest => "BC",
      :UserRequest                            => "BE",
      :CollateralInquiryAck                   => "BG",
      :TradingSessionListRequest              => "BI",
      :SecurityListUpdateReport               => "BK",
      :AllocationInstructionAlert             => "BM",
      :ContraryIntentionReport                => "BO",
      :SettlementObligationReport             => "BQ",
      :TradingSessionListUpdateReport         => "BS",
      :MarketDefinition                       => "BU",
      :ApplicationMessageRequest              => "BW",
      :ApplicationMessageReport               => "BY",
      :Email                                  => "C",
      :UserNotification                       => "CB",
      :StreamAssignmentReport                 => "CD",
      :PartyDetailsListRequest                => "CF",
      :NewOrderSingle                         => "D",
      :OrderCancelRequest                     => "F",
      :OrderStatusRequest                     => "H",
      :ListCancelRequest                      => "K",
      :ListStatusRequest                      => "M",
      :AllocationInstructionAck               => "P",
      :QuoteRequest                           => "R",
      :SettlementInstructions                 => "T",
      :MarketDataSnapshotFullRefresh          => "W",
      :MarketDataRequestReject                => "Y",
      :QuoteStatusRequest                     => "a",
      :SecurityDefinitionRequest              => "c",
      :SecurityStatusRequest                  => "e",
      :TradingSessionStatusRequest            => "g",
      :MassQuote                              => "i",
      :BidRequest                             => "k",
      :ListStrikePrice                        => "m",
      :RegistrationInstructions               => "o",
      :OrderMassCancelRequest                 => "q",
      :NewOrderCross                          => "s",
      :CrossOrderCancelRequest                => "u",
      :SecurityTypes                          => "w",
      :SecurityList                           => "y",
    }
  end
end
