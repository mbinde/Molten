"""
Glass manufacturer scrapers package.

Each manufacturer has its own module that exports a scrape() function
with a consistent interface.
"""

from . import boro_batch
from . import bullseye
from . import cim
from . import double_helix
from . import effetre_vetrofond
from . import glass_alchemy
from . import greasy
from . import molten_aura
from . import momka
from . import oceanside
from . import origin
from . import tag
from . import wissmach

__all__ = ['boro_batch', 'bullseye', 'cim', 'double_helix', 'effetre_vetrofond', 'glass_alchemy', 'greasy', 'molten_aura', 'momka', 'oceanside', 'origin', 'tag', 'wissmach']
