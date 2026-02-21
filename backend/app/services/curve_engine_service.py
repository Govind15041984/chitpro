def generate_temple_curve(
    first_prize: int,
    last_prize: int,
    months: int
) -> List[int]:
    """
    Month 1 = Foreman (no prize)
    Month 2..N = Generated curve
    """
    curve = []
    steps = months - 1  # since month1 is foreman
    base = first_prize
    end = last_prize

    # Temple style: slow rise initially, fast rise later (quadratic)
    for i in range(1, months):
        t = i / steps
        prize = int(base + (end - base) * (t ** 2.2))
        curve.append(prize)

    return curve
