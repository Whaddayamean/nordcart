-- seed-only model: changes only when the seed CSV changes
select channel_code, channel_group, is_digital
from {{ ref('channel_mapping') }}
