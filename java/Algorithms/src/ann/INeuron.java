package ann;

public interface INeuron {
    double getOutput();

    double activate();

    public String getName();

    void adjustWeights(double correctionDelta);
}
