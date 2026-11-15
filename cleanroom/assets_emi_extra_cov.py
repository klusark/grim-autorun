"""The EMI data of emi_cov_*.lua: cr_flat with seven shadows, two more than an actor has slots for (Actor::activateShadow:
"all shadow slots are in use")."""
import assets as A
import assets_emi as AE
import formats as F


def files():
    shadows = [("cov_shadow%d" % i, AE.LIGHT["name"] if i % 2 else "", (i - 3.0, 3.0 + i * 0.25, 0.5), ["floor"],
                (10 * i, 10 * i, 10 * i)) for i in range(7)]
    return {"cov_shadows7.setb": F.set_binary([dict(AE.CAMERA, name="cov_shadows7_0", background="cr_flat.til")], [AE.LIGHT],
                                              AE.emi_sectors(A.SETS["cr_flat"][1]), shadows=shadows)}
