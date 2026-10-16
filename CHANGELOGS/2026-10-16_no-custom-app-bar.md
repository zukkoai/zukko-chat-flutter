# Chat header cannot be replaced

## What
Removed the public `appBar` parameter from `ZukkoChat`. The page always renders the style's own header.

## Why
The header is part of the Zukko design; host apps must not be able to replace it.
