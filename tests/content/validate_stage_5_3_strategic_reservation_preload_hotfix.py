from pathlib import Path

root = Path(__file__).resolve().parents[2]
service_path = root / 'application/inventory/strategic_reservation_service.gd'
campaign_session_path = root / 'bootstrap/app/campaign_session.gd'

service = service_path.read_text(encoding='utf-8')
campaign_session = campaign_session_path.read_text(encoding='utf-8')

assert service.startswith('extends RefCounted')
assert 'class_name StrategicReservationService' not in service
assert 'const OperationResultScript = preload("res://core/results/operation_result.gd")' in service
assert 'const StrategicReservationStateScript = preload(' in service

# The early-preloaded service must not force the parser to resolve campaign,
# mission, item, route or registry global classes while CampaignSession parses.
for forbidden in [
    'CampaignItemState',
    'CampaignItemLocationState',
    'SquadTravelOperationState',
    'ActiveMissionState',
    'MissionDefinitionRegistry',
    '-> OperationResult',
    ': OperationResult',
]:
    assert forbidden not in service, forbidden

assert 'const StrategicReservationServiceScript = preload(' in campaign_session
assert 'strategic_reservation_service = StrategicReservationServiceScript.new()' in campaign_session

print('PASS — StrategicReservationService is fully isolated from early global-class resolution.')
