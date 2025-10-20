"""
Glass manufacturer scrapers package.

Each manufacturer has its own module that exports a scrape() function
with a consistent interface.
"""

from . import boro_batch
from . import bullseye
from . import chinese_boro
from . import cim
from . import delphi_superior
from . import double_helix
from . import effetre_vetrofond
from . import gaffer
from . import glass_alchemy
from . import greasy
from . import lunar
from . import molten_aura
from . import momka
from . import oceanside
from . import origin
from . import parramore
from . import pdx_tubing
from . import tag
from . import ust_glass
from . import wissmach
from . import youghiogheny

__all__ = ['boro_batch', 'bullseye', 'chinese_boro', 'cim', 'delphi_superior', 'double_helix', 'effetre_vetrofond', 'gaffer', 'glass_alchemy', 'greasy', 'lunar', 'molten_aura', 'momka', 'oceanside', 'origin', 'parramore', 'pdx_tubing', 'tag', 'ust_glass', 'wissmach', 'youghiogheny']
